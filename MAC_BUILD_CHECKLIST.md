# Mac Build Checklist

Use this checklist on a Mac with Xcode.

## 1. Required tools

- Xcode 13.2 or newer
- iOS 15.3 simulator or an iPhone running iOS 15.3
- Apple Developer account
- XcodeGen

Install XcodeGen:

```bash
brew install xcodegen
```

## 2. Generate the project

From this folder:

```bash
xcodegen generate
open ShadowLite.xcodeproj
```

## 3. Configure signing

In Xcode:

1. Select the `ShadowLite` app target.
2. Change `com.example.ShadowLite` to your own bundle identifier.
3. Select your development team.
4. Select the `ShadowLiteTunnel` extension target.
5. Change `com.example.ShadowLite.ShadowLiteTunnel` to match your app identifier plus `.ShadowLiteTunnel`.
6. Select the same development team.

The value in `VPNManager.swift` must match the extension bundle identifier:

```swift
configuration.providerBundleIdentifier = "your.bundle.id.ShadowLiteTunnel"
```

## 4. Enable capabilities

For both app and extension targets:

1. Open `Signing & Capabilities`.
2. Add `Network Extensions`.
3. Enable `Packet Tunnel Provider`.

If Xcode or Apple Developer Portal rejects this capability, the app cannot install a packet tunnel.

## 5. Build status

The project should build after signing is configured. The current engine provides HTTP/HTTPS proxy mode over Shadowsocks AEAD TCP.

Supported first-pass behavior:

- `aes-256-gcm`
- `chacha20-ietf-poly1305`
- HTTP absolute-URI proxy requests
- HTTPS `CONNECT` proxy requests

It does not provide full packet-level VPN forwarding for UDP or arbitrary IP traffic.

## 6. Install to iPhone

1. Connect the iPhone by USB.
2. Trust the Mac on the iPhone.
3. Select the iPhone as the run destination in Xcode.
4. Press Run.
5. When iOS asks to add VPN configuration, tap Allow.

## 7. Before real use

Do not use this as a daily VPN until:

- The Shadowsocks bridge is compiled and tested on real iOS hardware.
- DNS handling is tested.
- IPv4 and IPv6 routes are tested.
- Connection failures are handled cleanly.
- The app is tested on real iOS 15.3 hardware.
