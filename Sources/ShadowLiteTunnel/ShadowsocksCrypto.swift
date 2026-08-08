import CryptoKit
import Foundation
import Security

struct ShadowsocksCipher {
    enum Method: String {
        case aes256gcm = "aes-256-gcm"
        case chacha20ietfpoly1305 = "chacha20-ietf-poly1305"

        var keySize: Int {
            switch self {
            case .aes256gcm: return 32
            case .chacha20ietfpoly1305: return 32
            }
        }

        var saltSize: Int { keySize }
    }

    let method: Method
    let masterKey: Data

    init(methodName: String, password: String) throws {
        guard let method = Method(rawValue: methodName) else {
            throw TunnelError.unsupportedCipher(methodName)
        }
        self.method = method
        self.masterKey = Self.evpBytesToKey(password: password, keyLength: method.keySize)
    }

    func makeSession(salt: Data) -> ShadowsocksSession {
        let key = HKDF<Insecure.SHA1>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: masterKey),
            salt: salt,
            info: Data("ss-subkey".utf8),
            outputByteCount: method.keySize
        )
        return ShadowsocksSession(method: method, key: key)
    }

    static func randomSalt(size: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: size)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    private static func evpBytesToKey(password: String, keyLength: Int) -> Data {
        let passwordData = Data(password.utf8)
        var derived = Data()
        var previous = Data()

        while derived.count < keyLength {
            var input = Data()
            input.append(previous)
            input.append(passwordData)
            let digest = Insecure.MD5.hash(data: input)
            previous = Data(digest)
            derived.append(previous)
        }

        return derived.prefix(keyLength)
    }
}

final class ShadowsocksSession {
    private let method: ShadowsocksCipher.Method
    private let key: SymmetricKey
    private var encryptNonce = ShadowsocksNonce()
    private var decryptNonce = ShadowsocksNonce()

    init(method: ShadowsocksCipher.Method, key: SymmetricKey) {
        self.method = method
        self.key = key
    }

    func encrypt(_ payload: Data) throws -> Data {
        let nonce = try encryptNonce.next()
        switch method {
        case .aes256gcm:
            let sealed = try AES.GCM.seal(payload, using: key, nonce: AES.GCM.Nonce(data: nonce))
            var output = Data()
            output.append(sealed.ciphertext)
            output.append(sealed.tag)
            return output
        case .chacha20ietfpoly1305:
            let sealed = try ChaChaPoly.seal(payload, using: key, nonce: ChaChaPoly.Nonce(data: nonce))
            var output = Data()
            output.append(sealed.ciphertext)
            output.append(sealed.tag)
            return output
        }
    }

    func decrypt(_ payload: Data) throws -> Data {
        guard payload.count >= 16 else { throw TunnelError.invalidCiphertext }
        let nonce = try decryptNonce.next()
        let ciphertext = payload.dropLast(16)
        let tag = payload.suffix(16)

        switch method {
        case .aes256gcm:
            let box = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: nonce),
                ciphertext: Data(ciphertext),
                tag: Data(tag)
            )
            return try AES.GCM.open(box, using: key)
        case .chacha20ietfpoly1305:
            let box = try ChaChaPoly.SealedBox(
                nonce: ChaChaPoly.Nonce(data: nonce),
                ciphertext: Data(ciphertext),
                tag: Data(tag)
            )
            return try ChaChaPoly.open(box, using: key)
        }
    }
}

private struct ShadowsocksNonce {
    private var value = Data(repeating: 0, count: 12)

    mutating func next() throws -> Data {
        let current = value
        increment()
        return current
    }

    private mutating func increment() {
        for index in 0..<value.count {
            let next = value[index] &+ 1
            value[index] = next
            if next != 0 { break }
        }
    }
}
