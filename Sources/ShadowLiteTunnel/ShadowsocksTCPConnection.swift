import Foundation
import Network

final class ShadowsocksTCPConnection {
    private let configuration: TunnelConfiguration
    private let endpoint: ProxyEndpoint
    private var connection: NWConnection?
    private var encryptSession: ShadowsocksSession?
    private var decryptSession: ShadowsocksSession?
    private var receiveBuffer = Data()

    init(configuration: TunnelConfiguration, endpoint: ProxyEndpoint) {
        self.configuration = configuration
        self.endpoint = endpoint
    }

    func start(on queue: DispatchQueue, initialPayload: Data, completion: @escaping (Error?) -> Void) {
        guard let port = NWEndpoint.Port(rawValue: UInt16(configuration.port)) else {
            completion(TunnelError.invalidProviderConfiguration)
            return
        }

        let connection = NWConnection(host: NWEndpoint.Host(configuration.host), port: port, using: .tcp)
        self.connection = connection

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.sendHandshake(initialPayload: initialPayload, completion: completion)
            case .failed(let error):
                completion(error)
            default:
                break
            }
        }

        connection.start(queue: queue)
    }

    func send(_ data: Data, completion: @escaping (Error?) -> Void) {
        do {
            let encrypted = try encryptFrame(data)
            connection?.send(content: encrypted, completion: .contentProcessed(completion))
        } catch {
            completion(error)
        }
    }

    func receive(completion: @escaping (Data?, Error?) -> Void) {
        readNextFrame(completion: completion)
    }

    func close() {
        connection?.cancel()
        connection = nil
    }

    private func sendHandshake(initialPayload: Data, completion: @escaping (Error?) -> Void) {
        do {
            let cipher = try ShadowsocksCipher(methodName: configuration.method, password: configuration.password)
            let salt = ShadowsocksCipher.randomSalt(size: cipher.method.saltSize)
            let encryptionSession = cipher.makeSession(salt: salt)
            encryptSession = encryptionSession
            decryptSession = cipher.makeSession(salt: salt)

            guard let address = endpoint.socksAddress else {
                completion(TunnelError.invalidEndpoint)
                return
            }

            var payload = Data()
            payload.append(address)
            payload.append(initialPayload)

            var output = Data()
            output.append(salt)
            output.append(try encryptFrame(payload, using: encryptionSession))
            connection?.send(content: output, completion: .contentProcessed(completion))
        } catch {
            completion(error)
        }
    }

    private func encryptFrame(_ payload: Data) throws -> Data {
        guard let encryptSession else { throw TunnelError.engineNotReady }
        return try encryptFrame(payload, using: encryptSession)
    }

    private func encryptFrame(_ payload: Data, using session: ShadowsocksSession) throws -> Data {
        guard payload.count <= UInt16.max else { throw TunnelError.payloadTooLarge }
        var lengthBytes = Data()
        lengthBytes.append(UInt8((payload.count >> 8) & 0xff))
        lengthBytes.append(UInt8(payload.count & 0xff))

        var output = Data()
        output.append(try session.encrypt(lengthBytes))
        output.append(try session.encrypt(payload))
        return output
    }

    private func readNextFrame(completion: @escaping (Data?, Error?) -> Void) {
        readBytes(count: 18) { [weak self] encryptedLength, error in
            guard let self else { return }
            if let error {
                completion(nil, error)
                return
            }

            guard let encryptedLength,
                  let decryptSession = self.decryptSession else {
                completion(nil, TunnelError.engineNotReady)
                return
            }

            do {
                let lengthData = try decryptSession.decrypt(encryptedLength)
                guard lengthData.count == 2 else {
                    completion(nil, TunnelError.invalidCiphertext)
                    return
                }

                let length = (Int(lengthData[0]) << 8) | Int(lengthData[1])
                self.readBytes(count: length + 16) { encryptedPayload, payloadError in
                    if let payloadError {
                        completion(nil, payloadError)
                        return
                    }

                    guard let encryptedPayload else {
                        completion(nil, TunnelError.invalidCiphertext)
                        return
                    }

                    do {
                        completion(try decryptSession.decrypt(encryptedPayload), nil)
                    } catch {
                        completion(nil, error)
                    }
                }
            } catch {
                completion(nil, error)
            }
        }
    }

    private func readBytes(count: Int, completion: @escaping (Data?, Error?) -> Void) {
        if receiveBuffer.count >= count {
            let output = receiveBuffer.prefix(count)
            receiveBuffer.removeFirst(count)
            completion(Data(output), nil)
            return
        }

        connection?.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let data, !data.isEmpty {
                self.receiveBuffer.append(data)
            }

            if let error {
                completion(nil, error)
                return
            }

            if isComplete && self.receiveBuffer.count < count {
                completion(nil, TunnelError.connectionClosed)
                return
            }

            self.readBytes(count: count, completion: completion)
        }
    }
}
