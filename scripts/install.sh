#!/usr/bin/env bash
# Builds and installs Codex Notch into ~/Applications, then prints the hook config.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/build-app.sh"

TARGET="$HOME/Applications/CodexNotch.app"
mkdir -p "$HOME/Applications"
rm -rf "$TARGET"
ditto "$ROOT/build/CodexNotch.app" "$TARGET"

echo "==> installed $TARGET"
echo ""
echo "Add this to ~/.codex/config.toml so Codex reports turn events:"
echo ""
echo "  notify = [\"$TARGET/Contents/MacOS/codexnotch-hook\"]"
echo ""
echo "Then start it:"
echo ""
echo "  open \"$TARGET\""
