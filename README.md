# ShadowLite iOS

An iOS 15.3-compatible starter project for a Shadowsocks-style client.

## Current scope

- SwiftUI node list
- Add, edit, delete, and select Shadowsocks nodes
- Import `ss://` links, base64 subscription text, and HTTP(S) subscription URLs
- Local JSON persistence
- VPN connection state model
- `NetworkExtension` packet-tunnel extension entry point
- Clear integration boundary for the Shadowsocks/tun2socks engine
- XcodeGen `Project.yml` for generating the Xcode project on macOS
- Tunnel configuration validation inside the Packet Tunnel extension
- Local HTTP/HTTPS proxy bridge using Shadowsocks AEAD TCP transport

## Important limitation

The packet tunnel currently contains a local HTTP/HTTPS proxy bridge over Shadowsocks AEAD TCP. A full Shadowrocket-style VPN client still needs:

1. An Apple Network Extension entitlement.
2. A reviewed Shadowsocks transport implementation.
3. A packet-level TUN-to-SOCKS/SS forwarding engine for full-device TCP/UDP mode.
4. DNS handling and leak prevention.
5. Code signing on macOS with Xcode.

The current engine is an HTTP/HTTPS proxy bridge. It is not a full packet-level VPN and does not forward UDP or arbitrary IP packets.

## Xcode setup

For the full build flow, see `MAC_BUILD_CHECKLIST.md`.
For scripted device installation, see `INSTALL_ON_MAC.md`.
For a no-Mac cloud build, see `.github/workflows/build-ipa.yml`.
For GitHub upload and Windows-to-TrollStore install steps, see `GITHUB_BUILD_STEPS.md`.

Preferred setup with XcodeGen:

1. On a Mac, install Xcode and XcodeGen.
2. Open Terminal in this folder.
3. Run `xcodegen generate`.
4. Open `ShadowLite.xcodeproj`.
5. Set the deployment target to iOS 15.3 if Xcode does not pick it up automatically.
6. Enable the Network Extensions capability and select Packet Tunnel Provider.
7. Replace `com.example.ShadowLite` with your real bundle identifier.
8. Test HTTP/HTTPS proxy mode first, then add a reviewed Shadowsocks/tun2socks implementation for full-device mode if needed.

Manual setup:

1. Create a new iOS App project named `ShadowLite`.
2. Set the deployment target to iOS 15.3.
3. Add the Swift files from `Sources/ShadowLite`.
4. Add a Packet Tunnel Provider extension target named `ShadowLiteTunnel`.
5. Add `Sources/ShadowLiteTunnel/PacketTunnelProvider.swift` to that target.
6. Enable the Network Extensions capability and select Packet Tunnel Provider.
7. Set the app and extension bundle identifiers to matching values.
8. Test HTTP/HTTPS proxy mode first, then add a reviewed Shadowsocks/tun2socks implementation for full-device mode if needed.

The app UI is intentionally separated from the tunnel engine so the protocol implementation can be replaced without rewriting the node management screens.

## Engine integration boundary

For the production tunnel work, see `ENGINE_INTEGRATION.md`.

The current transport starts through `ProxyTunnelEngine` in:

- `Sources/ShadowLiteTunnel/TunnelEngine.swift`
- `Sources/ShadowLiteTunnel/PacketTunnelProvider.swift`

The app passes only the selected Shadowsocks node into the extension through `NETunnelProviderProtocol.providerConfiguration`.
