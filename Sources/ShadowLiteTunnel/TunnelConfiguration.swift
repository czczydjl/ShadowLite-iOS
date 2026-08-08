import NetworkExtension

struct TunnelConfiguration {
    let name: String
    let host: String
    let port: Int
    let password: String
    let method: String

    init(protocolConfiguration: NETunnelProviderProtocol) throws {
        guard let providerConfiguration = protocolConfiguration.providerConfiguration,
              let name = providerConfiguration["name"] as? String,
              let host = providerConfiguration["host"] as? String,
              let port = providerConfiguration["port"] as? Int,
              let password = providerConfiguration["password"] as? String,
              let method = providerConfiguration["method"] as? String else {
            throw TunnelError.invalidProviderConfiguration
        }

        self.name = name
        self.host = host
        self.port = port
        self.password = password
        self.method = method
    }
}
