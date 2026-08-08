import Foundation
import Network

final class LocalHTTPProxy {
    private let configuration: TunnelConfiguration
    private let listenPort: UInt16
    private let queue = DispatchQueue(label: "ShadowLite.LocalHTTPProxy")
    private var listener: NWListener?

    init(configuration: TunnelConfiguration, listenPort: UInt16) {
        self.configuration = configuration
        self.listenPort = listenPort
    }

    func start() throws {
        let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: listenPort)!)
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else {
                connection.cancel()
                return
            }
            let session = HTTPProxySession(client: connection, configuration: self.configuration)
            session.start(on: self.queue)
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }
}

private final class HTTPProxySession {
    private let client: NWConnection
    private let configuration: TunnelConfiguration
    private var remote: ShadowsocksTCPConnection?
    private var requestBuffer = Data()
    private var queue: DispatchQueue?

    init(client: NWConnection, configuration: TunnelConfiguration) {
        self.client = client
        self.configuration = configuration
    }

    func start(on queue: DispatchQueue) {
        self.queue = queue
        client.start(queue: queue)
        readHeader()
    }

    private func readHeader() {
        client.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let data, !data.isEmpty {
                self.requestBuffer.append(data)
            }

            if error != nil || isComplete {
                self.close()
                return
            }

            if let headerRange = self.requestBuffer.range(of: Data("\r\n\r\n".utf8)) {
                let headerEnd = headerRange.upperBound
                let header = self.requestBuffer.prefix(headerEnd)
                let body = self.requestBuffer.dropFirst(headerEnd)
                self.handleHeader(Data(header), initialBody: Data(body))
                return
            }

            self.readHeader()
        }
    }

    private func handleHeader(_ header: Data, initialBody: Data) {
        guard let headerText = String(data: header, encoding: .utf8),
              let firstLine = headerText.components(separatedBy: "\r\n").first else {
            close()
            return
        }

        let parts = firstLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count >= 2 else {
            close()
            return
        }

        if parts[0].uppercased() == "CONNECT" {
            openConnectTunnel(target: parts[1])
        } else {
            forwardHTTP(method: parts[0], urlString: parts[1], headerText: headerText, initialBody: initialBody)
        }
    }

    private func openConnectTunnel(target: String) {
        guard let endpoint = ProxyEndpoint(connectTarget: target),
              let queue else {
            close()
            return
        }

        let remote = ShadowsocksTCPConnection(configuration: configuration, endpoint: endpoint)
        self.remote = remote
        remote.start(on: queue, initialPayload: Data()) { [weak self] error in
            guard let self else { return }
            if error != nil {
                self.close()
                return
            }

            self.client.send(content: Data("HTTP/1.1 200 Connection Established\r\n\r\n".utf8), completion: .contentProcessed { [weak self] error in
                guard let self else { return }
                if error != nil {
                    self.close()
                    return
                }
                self.pipeClientToRemote()
                self.pipeRemoteToClient()
            })
        }
    }

    private func forwardHTTP(method: String, urlString: String, headerText: String, initialBody: Data) {
        guard let url = URL(string: urlString),
              let host = url.host,
              let queue else {
            close()
            return
        }

        let port = url.port ?? (url.scheme?.lowercased() == "https" ? 443 : 80)
        let endpoint = ProxyEndpoint(host: host, port: port)
        let rewrittenHeader = rewriteAbsoluteURIRequest(headerText: headerText, url: url)
        var payload = Data(rewrittenHeader.utf8)
        payload.append(initialBody)

        let remote = ShadowsocksTCPConnection(configuration: configuration, endpoint: endpoint)
        self.remote = remote
        remote.start(on: queue, initialPayload: payload) { [weak self] error in
            guard let self else { return }
            if error != nil {
                self.close()
                return
            }
            self.pipeClientToRemote()
            self.pipeRemoteToClient()
        }
    }

    private func rewriteAbsoluteURIRequest(headerText: String, url: URL) -> String {
        var lines = headerText.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return headerText }

        let parts = firstLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count >= 3 else { return headerText }

        let path = url.path.isEmpty ? "/" : url.path
        let query = url.query.map { "?\($0)" } ?? ""
        lines[0] = "\(parts[0]) \(path)\(query) \(parts[2])"
        return lines.joined(separator: "\r\n")
    }

    private func pipeClientToRemote() {
        client.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let data, !data.isEmpty {
                self.remote?.send(data) { [weak self] sendError in
                    guard let self else { return }
                    if sendError != nil {
                        self.close()
                        return
                    }
                    if !isComplete {
                        self.pipeClientToRemote()
                    }
                }
                return
            }

            if error != nil || isComplete {
                self.close()
            } else {
                self.pipeClientToRemote()
            }
        }
    }

    private func pipeRemoteToClient() {
        remote?.receive { [weak self] data, error in
            guard let self else { return }
            if error != nil {
                self.close()
                return
            }

            guard let data, !data.isEmpty else {
                self.close()
                return
            }

            self.client.send(content: data, completion: .contentProcessed { [weak self] sendError in
                guard let self else { return }
                if sendError != nil {
                    self.close()
                } else {
                    self.pipeRemoteToClient()
                }
            })
        }
    }

    private func close() {
        remote?.close()
        client.cancel()
    }
}

struct ProxyEndpoint {
    let host: String
    let port: Int

    init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    init?(connectTarget: String) {
        let parts = connectTarget.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let port = Int(parts[1]) else { return nil }
        host = parts[0]
        self.port = port
    }

    var socksAddress: Data? {
        guard let hostData = host.data(using: .utf8), hostData.count <= 255 else { return nil }
        var data = Data([0x03, UInt8(hostData.count)])
        data.append(hostData)
        data.append(UInt8((port >> 8) & 0xff))
        data.append(UInt8(port & 0xff))
        return data
    }
}
