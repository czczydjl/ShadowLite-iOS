# Install On Mac

This project cannot be installed to an iPhone from Windows. iOS requires Xcode signing and a macOS toolchain.

## No Mac: GitHub Actions

The repository includes `.github/workflows/build-ipa.yml`. Push this folder to a GitHub repository, then:

1. Open the repository's `Actions` tab.
2. Select `Build ShadowLite IPA`.
3. Click `Run workflow`.
4. Download the `ShadowLite-unsigned-ipa` artifact.
5. Send the IPA to the iPhone using Files, AirDrop, or a local web transfer.
6. Open it with TrollStore and choose `Install`.

The workflow uses a macOS runner and does not require your own Mac. It is an unsigned test build intended for TrollStore on your own jailbroken device.

## One-command path

On a Mac, open Terminal in this folder and run:

```bash
brew install xcodegen
chmod +x Scripts/*.sh
DEVICE_ID=<your-iphone-udid> \
BASE_BUNDLE_ID=com.yourname.ShadowLite \
DEVELOPMENT_TEAM=<your-team-id> \
Scripts/build_and_install.sh
```

To list connected iPhones:

```bash
xcrun xctrace list devices
```

## What the script does

1. Rewrites the app and tunnel bundle identifiers.
2. Rewrites `AppConfig.tunnelProviderBundleIdentifier`.
3. Generates `ShadowLite.xcodeproj`.
4. Builds the app for the connected iPhone.
5. Installs the built `.app` using `devicectl` or `ios-deploy`.

## Manual fallback

If the script fails because Apple rejects signing or Network Extension entitlement:

1. Run `xcodegen generate`.
2. Open `ShadowLite.xcodeproj`.
3. Configure signing for `ShadowLite` and `ShadowLiteTunnel`.
4. Enable `Network Extensions` with `Packet Tunnel Provider`.
5. Select the iPhone in Xcode.
6. Press Run.

## Required Apple account state

The app target and extension target both need valid signing. Packet Tunnel Provider must be available for your developer account. If Apple blocks this entitlement, installation cannot complete.
