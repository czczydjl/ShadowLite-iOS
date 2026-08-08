import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var engine: TunnelEngine?

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        do {
            guard let protocolConfiguration = protocolConfiguration as? NETunnelProviderProtocol else {
                throw TunnelError.invalidProviderConfiguration
            }

            let configuration = try TunnelConfiguration(protocolConfiguration: protocolConfiguration)
            let engine = ProxyTunnelEngine(provider: self, configuration: configuration)
            self.engine = engine

            engine.start { error in
                completionHandler(error)
            }
        } catch {
            completionHandler(error)
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        engine?.stop {
            completionHandler()
        }
    }
}
