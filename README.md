# ShadowLite iOS

An iOS 15.3-compatible lightweight proxy client prototype.

## Current scope

- SwiftUI node list with add, edit, delete, select, and import flows
- Clash YAML subscription import for VLESS TCP Reality/Vision nodes
- `ss://` Shadowsocks link import retained for compatibility
- Local JSON persistence using `UserDefaults`
- `NetworkExtension` packet-tunnel entry point
- `ShadowBoxCore` gomobile wrapper around sing-box `v1.13.16`
- System HTTP/HTTPS proxy mode backed by sing-box `mixed` inbound
- GitHub Actions unsigned IPA build for TrollStore-style installation

## Engine mode

This version starts sing-box inside the packet-tunnel extension and exposes a local `mixed` proxy on `127.0.0.1:20808`.
The Network Extension then sets iOS HTTP/HTTPS proxy settings to that local proxy.

This supports browser and app traffic that respects the iOS HTTP/HTTPS proxy settings. It is not yet a full packet-level TUN VPN, so UDP and apps that bypass system proxy settings may not be covered.

## Supported protocols

- VLESS TCP Reality/Vision from Clash YAML subscriptions
- Shadowsocks through sing-box outbound generation

The VLESS importer maps these Clash fields into sing-box JSON:

- `server`, `port`, `uuid`
- `flow: xtls-rprx-vision`
- `tls: true`
- `servername`
- `client-fingerprint`
- `reality-opts.public-key`
- `reality-opts.short-id`

## Cloud build

The GitHub Actions workflow:

1. Installs XcodeGen.
2. Installs Go and gomobile.
3. Builds `ThirdParty/ShadowBoxCore/build/ShadowBoxCore.xcframework`.
4. Generates the Xcode project from `Project.yml`.
5. Builds an unsigned iOS IPA.
6. Uploads `ShadowLite-unsigned.ipa` as a workflow artifact.

## Local Mac build

For a local Mac build:

1. Install Xcode, XcodeGen, Go, and gomobile.
2. From `ThirdParty/ShadowBoxCore`, run `go mod tidy`.
3. Build `ShadowBoxCore.xcframework` with gomobile.
4. Run `xcodegen generate`.
5. Build the `ShadowLite` scheme for iOS.

## Limitations

- Full TUN routing is not implemented yet.
- UDP forwarding is not implemented yet.
- The IPA is unsigned and intended for TrollStore/rootless-jailbreak testing.
- The bundle IDs are still `com.example.*` and should be changed for production signing.
