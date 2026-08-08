# Shadowsocks Engine Integration

The current app is intentionally split into two layers:

- App layer: UI, node storage, subscription import, VPN profile creation.
- Tunnel layer: Network Extension entry point and engine boundary.

The current engine implements a local HTTP/HTTPS proxy bridge over Shadowsocks AEAD TCP. A full Shadowrocket-style client still needs packet-level forwarding for UDP and arbitrary IP traffic.

## Current files

- `Sources/ShadowLite/VPNManager.swift` creates the iOS VPN profile.
- `Sources/ShadowLiteTunnel/PacketTunnelProvider.swift` starts the extension.
- `Sources/ShadowLiteTunnel/TunnelConfiguration.swift` validates the selected node.
- `Sources/ShadowLiteTunnel/TunnelEngine.swift` selects the active engine.
- `Sources/ShadowLiteTunnel/LocalHTTPProxy.swift` runs the local HTTP/HTTPS proxy.
- `Sources/ShadowLiteTunnel/ShadowsocksTCPConnection.swift` connects to the Shadowsocks server.
- `Sources/ShadowLiteTunnel/ShadowsocksCrypto.swift` implements AEAD framing for supported ciphers.

## Recommended implementation path

1. Keep `TunnelEngine` as the app's boundary.
2. Keep `ProxyTunnelEngine` for HTTP/HTTPS proxy mode.
3. Add a packet-forwarding engine when full-device TCP/UDP forwarding is required.
4. Configure `NEPacketTunnelNetworkSettings`.
5. Forward packets from the TUN interface to the Shadowsocks transport for full-device mode.
6. Add DNS settings and route rules.
7. Stop the engine cleanly when iOS stops the tunnel.

## Minimum behavior for a full packet engine

The real engine should:

- Validate method, host, port, and password.
- Create a virtual IPv4 address for the tunnel interface.
- Set default IPv4 routes when full-tunnel mode is enabled.
- Configure DNS servers explicitly.
- Forward TCP and UDP traffic.
- Cancel all tasks when `stopTunnel` is called.
- Return clear errors to `completionHandler`.

## Example full packet replacement shape

```swift
final class ShadowsocksTunnelEngine: TunnelEngine {
    private let provider: NEPacketTunnelProvider
    private let configuration: TunnelConfiguration

    init(provider: NEPacketTunnelProvider, configuration: TunnelConfiguration) {
        self.provider = provider
        self.configuration = configuration
    }

    func start(completion: @escaping (Error?) -> Void) {
        // 1. Build NEPacketTunnelNetworkSettings.
        // 2. Apply settings with provider.setTunnelNetworkSettings.
        // 3. Start the Shadowsocks transport.
        // 4. Start TUN packet forwarding.
    }

    func stop(completion: @escaping () -> Void) {
        // Stop transport and packet forwarding.
        completion()
    }
}
```

For full packet mode, replace this line in `PacketTunnelProvider.swift`:

```swift
let engine = ProxyTunnelEngine(provider: self, configuration: configuration)
```

with:

```swift
let engine = PacketForwardingTunnelEngine(provider: self, configuration: configuration)
```

## Why this is separate

Shadowsocks encryption and packet forwarding are security-sensitive. Keeping the implementation behind `TunnelEngine` makes the app easier to audit and prevents UI code from depending on a specific transport library.
