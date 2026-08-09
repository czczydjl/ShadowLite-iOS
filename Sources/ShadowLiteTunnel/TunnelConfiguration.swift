import NetworkExtension

struct TunnelConfiguration {
    enum ProtocolKind: String {
        case shadowsocks
        case vless
    }

    let name: String
    let host: String
    let port: Int
    let protocolKind: ProtocolKind
    let password: String
    let method: String
    let uuid: String
    let flow: String
    let tlsEnabled: Bool
    let serverName: String
    let fingerprint: String
    let realityPublicKey: String
    let realityShortID: String

    init(protocolConfiguration: NETunnelProviderProtocol) throws {
        guard let providerConfiguration = protocolConfiguration.providerConfiguration,
              let name = providerConfiguration["name"] as? String,
              let host = providerConfiguration["host"] as? String,
              let port = providerConfiguration["port"] as? Int else {
            throw TunnelError.invalidProviderConfiguration
        }

        self.name = name
        self.host = host
        self.port = port
        self.protocolKind = ProtocolKind(rawValue: providerConfiguration["protocolKind"] as? String ?? "shadowsocks") ?? .shadowsocks
        self.password = providerConfiguration["password"] as? String ?? ""
        self.method = providerConfiguration["method"] as? String ?? ""
        self.uuid = providerConfiguration["uuid"] as? String ?? ""
        self.flow = providerConfiguration["flow"] as? String ?? ""
        self.tlsEnabled = providerConfiguration["tlsEnabled"] as? Bool ?? false
        self.serverName = providerConfiguration["serverName"] as? String ?? ""
        self.fingerprint = providerConfiguration["fingerprint"] as? String ?? "chrome"
        self.realityPublicKey = providerConfiguration["realityPublicKey"] as? String ?? ""
        self.realityShortID = providerConfiguration["realityShortID"] as? String ?? ""

        switch protocolKind {
        case .shadowsocks:
            guard !password.isEmpty, !method.isEmpty else {
                throw TunnelError.invalidProviderConfiguration
            }
        case .vless:
            guard !uuid.isEmpty else {
                throw TunnelError.invalidProviderConfiguration
            }
        }
    }
}
