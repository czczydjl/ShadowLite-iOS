import Foundation
import NetworkExtension

@MainActor
final class VPNManager: ObservableObject {
    enum State: String {
        case disconnected
        case connecting
        case connected
        case failed
    }

    @Published private(set) var state: State = .disconnected
    @Published var errorMessage: String?

    private var manager: NETunnelProviderManager?
    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshStatus()
            }
        }
    }

    func connect(using node: ProxyNode) async {
        state = .connecting
        errorMessage = nil

        do {
            let manager = try await loadManager()
            let configuration = NETunnelProviderProtocol()
            configuration.providerBundleIdentifier = AppConfig.tunnelProviderBundleIdentifier
            configuration.serverAddress = node.host
            configuration.providerConfiguration = [
                "name": node.name,
                "host": node.host,
                "port": node.port,
                "password": node.password,
                "method": node.method
            ]

            manager.protocolConfiguration = configuration
            manager.localizedDescription = "ShadowLite"
            manager.isEnabled = true
            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()
            self.manager = manager
            try manager.connection.startVPNTunnel()
            refreshStatus()
        } catch {
            state = .failed
            errorMessage = error.localizedDescription
        }
    }

    func disconnect() {
        manager?.connection.stopVPNTunnel()
        state = .disconnected
    }

    func refreshStatus() {
        guard let status = manager?.connection.status else {
            state = .disconnected
            return
        }

        switch status {
        case .connected:
            state = .connected
        case .connecting, .reasserting:
            state = .connecting
        case .disconnecting:
            state = .connecting
        case .disconnected, .invalid:
            state = .disconnected
        @unknown default:
            state = .failed
        }
    }

    private func loadManager() async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        return managers.first ?? NETunnelProviderManager()
    }
}
