#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: Scripts/configure_bundle.sh <base.bundle.id> [development_team_id]"
  echo "Example: Scripts/configure_bundle.sh com.yourname.ShadowLite ABCDE12345"
  exit 64
fi

BASE_BUNDLE_ID="$1"
DEVELOPMENT_TEAM="${2:-}"
TUNNEL_BUNDLE_ID="${BASE_BUNDLE_ID}.ShadowLiteTunnel"

python3 - "$BASE_BUNDLE_ID" "$TUNNEL_BUNDLE_ID" "$DEVELOPMENT_TEAM" <<'PY'
from pathlib import Path
import sys

base_bundle_id, tunnel_bundle_id, team = sys.argv[1], sys.argv[2], sys.argv[3]

project = Path("Project.yml")
lines = project.read_text().splitlines()
out = []
current_target = None

for line in lines:
    stripped = line.strip()
    if line.startswith("  ShadowLite:"):
        current_target = "app"
    elif line.startswith("  ShadowLiteTunnel:"):
        current_target = "tunnel"
    elif line.startswith("  ") and stripped.endswith(":") and not line.startswith("    "):
        current_target = None

    if stripped.startswith("PRODUCT_BUNDLE_IDENTIFIER:"):
        indent = line[: len(line) - len(line.lstrip())]
        if current_target == "app":
            out.append(f"{indent}PRODUCT_BUNDLE_IDENTIFIER: {base_bundle_id}")
            continue
        if current_target == "tunnel":
            out.append(f"{indent}PRODUCT_BUNDLE_IDENTIFIER: {tunnel_bundle_id}")
            continue

    out.append(line)

text = "\n".join(out) + "\n"

if team:
    if "DEVELOPMENT_TEAM:" in text:
        lines = []
        for line in text.splitlines():
            if line.strip().startswith("DEVELOPMENT_TEAM:"):
                indent = line[: len(line) - len(line.lstrip())]
                lines.append(f"{indent}DEVELOPMENT_TEAM: {team}")
            else:
                lines.append(line)
        text = "\n".join(lines) + "\n"
    else:
        text = text.replace("SWIFT_VERSION: \"5.5\"", f"SWIFT_VERSION: \"5.5\"\n    DEVELOPMENT_TEAM: {team}")

project.write_text(text)

app_config = Path("Sources/ShadowLite/AppConfig.swift")
app_config.write_text(
    "enum AppConfig {\n"
    f"    static let tunnelProviderBundleIdentifier = \"{tunnel_bundle_id}\"\n"
    "}\n"
)
PY

echo "Configured app bundle id: ${BASE_BUNDLE_ID}"
echo "Configured tunnel bundle id: ${TUNNEL_BUNDLE_ID}"
if [[ -n "$DEVELOPMENT_TEAM" ]]; then
  echo "Configured development team: ${DEVELOPMENT_TEAM}"
fi
