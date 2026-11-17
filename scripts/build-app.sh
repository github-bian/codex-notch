#!/usr/bin/env bash
# Builds CodexNotch.app (ad-hoc signed) into ./build.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="${VERSION:-0.1.0}"
APP="$ROOT/build/CodexNotch.app"

echo "==> building (release)"
swift build -c release --disable-sandbox --product CodexNotch
swift build -c release --disable-sandbox --product codexnotch-hook
BIN="$(swift build -c release --disable-sandbox --show-bin-path)"

echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/CodexNotch" "$APP/Contents/MacOS/CodexNotch"
cp "$BIN/codexnotch-hook" "$APP/Contents/MacOS/codexnotch-hook"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Codex Notch</string>
  <key>CFBundleDisplayName</key><string>Codex Notch</string>
  <key>CFBundleIdentifier</key><string>io.github.github-bian.CodexNotch</string>
  <key>CFBundleExecutable</key><string>CodexNotch</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT licensed. Unofficial community project.</string>
</dict>
</plist>
PLIST

# Ad-hoc signature is enough for local use. Distribution needs a Developer ID.
if /usr/bin/codesign --force --sign - "$APP" >/dev/null 2>&1; then
  echo "==> ad-hoc signed"
else
  echo "==> warning: codesign failed; Gatekeeper may complain"
fi

echo "==> done: $APP"
