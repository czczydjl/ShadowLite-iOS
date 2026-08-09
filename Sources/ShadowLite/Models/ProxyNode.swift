import Foundation

struct ProxyNode: Identifiable, Codable, Equatable {
    enum ProtocolKind: String, Codable, CaseIterable {
        case shadowsocks
        case vless

        var displayName: String {
            switch self {
            case .shadowsocks:
                return "Shadowsocks"
            case .vless:
                return "VLESS Reality"
            }
        }
    }

    let id: UUID
    var name: String
    var host: String
    var port: Int
    var protocolKind: ProtocolKind
    var password: String
    var method: String
    var uuid: String
    var flow: String
    var tlsEnabled: Bool
    var serverName: String
    var fingerprint: String
    var realityPublicKey: String
    var realityShortID: String

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int,
        protocolKind: ProtocolKind = .shadowsocks,
        password: String,
        method: String,
        uuid: String = "",
        flow: String = "",
        tlsEnabled: Bool = false,
        serverName: String = "",
        fingerprint: String = "chrome",
        realityPublicKey: String = "",
        realityShortID: String = ""
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.protocolKind = protocolKind
        self.password = password
        self.method = method
        self.uuid = uuid
        self.flow = flow
        self.tlsEnabled = tlsEnabled
        self.serverName = serverName
        self.fingerprint = fingerprint
        self.realityPublicKey = realityPublicKey
        self.realityShortID = realityShortID
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case host
        case port
        case protocolKind
        case password
        case method
        case uuid
        case flow
        case tlsEnabled
        case serverName
        case fingerprint
        case realityPublicKey
        case realityShortID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        host = try container.decode(String.self, forKey: .host)
        port = try container.decode(Int.self, forKey: .port)
        protocolKind = try container.decodeIfPresent(ProtocolKind.self, forKey: .protocolKind) ?? .shadowsocks
        password = try container.decodeIfPresent(String.self, forKey: .password) ?? ""
        method = try container.decodeIfPresent(String.self, forKey: .method) ?? ""
        uuid = try container.decodeIfPresent(String.self, forKey: .uuid) ?? ""
        flow = try container.decodeIfPresent(String.self, forKey: .flow) ?? ""
        tlsEnabled = try container.decodeIfPresent(Bool.self, forKey: .tlsEnabled) ?? false
        serverName = try container.decodeIfPresent(String.self, forKey: .serverName) ?? ""
        fingerprint = try container.decodeIfPresent(String.self, forKey: .fingerprint) ?? "chrome"
        realityPublicKey = try container.decodeIfPresent(String.self, forKey: .realityPublicKey) ?? ""
        realityShortID = try container.decodeIfPresent(String.self, forKey: .realityShortID) ?? ""
    }
}
