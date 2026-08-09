import NetworkExtension
#if canImport(ShadowBoxCore)
import ShadowBoxCore
#endif

protocol TunnelEngine {
    func start(completion: @escaping (Error?) -> Void)
    func stop(completion: @escaping () -> Void)
}

final class SingBoxTunnelEngine: TunnelEngine {
    private let provider: NEPacketTunnelProvider
    private let configuration: TunnelConfiguration

    init(provider: NEPacketTunnelProvider, configuration: TunnelConfiguration) {
        self.provider = provider
        self.configuration = configuration
    }

    func start(completion: @escaping (Error?) -> Void) {
        do {
            let configContent = try SingBoxConfigFactory.makeConfig(configuration: configuration)
            #if canImport(ShadowBoxCore)
            let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let workingURL = libraryURL.appendingPathComponent("ShadowBoxCore", isDirectory: true)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("ShadowBoxCoreTemp", isDirectory: true)
            try FileManager.default.createDirectory(at: workingURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
            try ShadowboxcoreCheckConfig(configContent)
            try ShadowboxcoreStart(configContent, workingURL.path, tempURL.path)

            let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: configuration.host)
            settings.mtu = 1500
            settings.ipv4Settings = NEIPv4Settings(
                addresses: ["198.18.0.1"],
                subnetMasks: ["255.255.255.0"]
            )

            let proxySettings = NEProxySettings()
            proxySettings.httpEnabled = true
            proxySettings.httpServer = NEProxyServer(address: "127.0.0.1", port: SingBoxConfigFactory.localProxyPort)
            proxySettings.httpsEnabled = true
            proxySettings.httpsServer = NEProxyServer(address: "127.0.0.1", port: SingBoxConfigFactory.localProxyPort)
            proxySettings.excludeSimpleHostnames = true
            proxySettings.matchDomains = [""]
            settings.proxySettings = proxySettings

            provider.setTunnelNetworkSettings(settings) { error in
                completion(error)
            }
            #else
            throw TunnelError.singBoxCoreMissing
            #endif
        } catch {
            completion(error)
        }
    }

    func stop(completion: @escaping () -> Void) {
        #if canImport(ShadowBoxCore)
        _ = try? ShadowboxcoreStop()
        #endif
        completion()
    }
}

final class ProxyTunnelEngine: TunnelEngine {
    private let provider: NEPacketTunnelProvider
    private let configuration: TunnelConfiguration
    private var proxy: LocalHTTPProxy?

    init(provider: NEPacketTunnelProvider, configuration: TunnelConfiguration) {
        self.provider = provider
        self.configuration = configuration
    }

    func start(completion: @escaping (Error?) -> Void) {
        let localPort: UInt16 = 9090
        let proxy = LocalHTTPProxy(configuration: configuration, listenPort: localPort)
        self.proxy = proxy

        do {
            try proxy.start()
        } catch {
            completion(error)
            return
        }

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: configuration.host)
        settings.mtu = 1500
        settings.ipv4Settings = NEIPv4Settings(
            addresses: ["198.18.0.1"],
            subnetMasks: ["255.255.255.0"]
        )

        let proxySettings = NEProxySettings()
        proxySettings.httpEnabled = true
        proxySettings.httpServer = NEProxyServer(address: "127.0.0.1", port: Int(localPort))
        proxySettings.httpsEnabled = true
        proxySettings.httpsServer = NEProxyServer(address: "127.0.0.1", port: Int(localPort))
        proxySettings.excludeSimpleHostnames = true
        proxySettings.matchDomains = [""]
        settings.proxySettings = proxySettings

        provider.setTunnelNetworkSettings(settings) { error in
            completion(error)
        }
    }

    func stop(completion: @escaping () -> Void) {
        proxy?.stop()
        proxy = nil
        completion()
    }
}

enum TunnelError: LocalizedError {
    case invalidProviderConfiguration
    case engineNotReady
    case unsupportedCipher(String)
    case invalidCiphertext
    case invalidEndpoint
    case payloadTooLarge
    case connectionClosed
    case singBoxCoreMissing

    var errorDescription: String? {
        switch self {
        case .invalidProviderConfiguration:
            return "The VPN provider configuration is missing required proxy fields."
        case .engineNotReady:
            return "The Shadowsocks engine is not ready."
        case .unsupportedCipher(let method):
            return "Unsupported Shadowsocks cipher: \(method)."
        case .invalidCiphertext:
            return "Received invalid Shadowsocks ciphertext."
        case .invalidEndpoint:
            return "The target endpoint is invalid."
        case .payloadTooLarge:
            return "The Shadowsocks payload is too large."
        case .connectionClosed:
            return "The remote connection closed."
        case .singBoxCoreMissing:
            return "ShadowBoxCore is missing. Rebuild the IPA with the sing-box core workflow."
        }
    }
}
