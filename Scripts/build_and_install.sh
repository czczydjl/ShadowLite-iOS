#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script must run on macOS with Xcode installed."
  exit 70
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is missing. Install it with: brew install xcodegen"
  exit 69
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is missing. Install Xcode and run: sudo xcode-select -s /Applications/Xcode.app"
  exit 69
fi

BASE_BUNDLE_ID="${BASE_BUNDLE_ID:-}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"
DEVICE_ID="${DEVICE_ID:-}"

if [[ -n "$BASE_BUNDLE_ID" ]]; then
  Scripts/configure_bundle.sh "$BASE_BUNDLE_ID" "$DEVELOPMENT_TEAM"
fi

xcodegen generate

if [[ -z "$DEVICE_ID" ]]; then
  echo "DEVICE_ID is not set. Connected devices:"
  xcrun xctrace list devices 2>/dev/null || true
  echo
  echo "Run again with:"
  echo "DEVICE_ID=<your-device-udid> BASE_BUNDLE_ID=<your.bundle.id> DEVELOPMENT_TEAM=<teamid> Scripts/build_and_install.sh"
  exit 64
fi

DERIVED_DATA_PATH="${PWD}/build/DerivedData"

xcodebuild \
  -project ShadowLite.xcodeproj \
  -scheme ShadowLite \
  -configuration Debug \
  -destination "id=${DEVICE_ID}" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

APP_PATH="$(find "$DERIVED_DATA_PATH" -path '*Debug-iphoneos/ShadowLite.app' -type d | head -n 1)"

if [[ -z "$APP_PATH" ]]; then
  echo "Build succeeded but ShadowLite.app was not found under ${DERIVED_DATA_PATH}."
  exit 66
fi

if xcrun devicectl --help >/dev/null 2>&1; then
  xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"
elif command -v ios-deploy >/dev/null 2>&1; then
  ios-deploy --id "$DEVICE_ID" --bundle "$APP_PATH"
else
  echo "Built app at: $APP_PATH"
  echo "Install tool missing. Use Xcode Run, install Xcode 15 devicectl, or install ios-deploy."
  exit 69
fi

echo "Installed ShadowLite on device ${DEVICE_ID}."
