#!/usr/bin/env bash
# Builds everything and runs the executable check suite (XCTest is not available
# with Command Line Tools alone).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

swift build --disable-sandbox
BIN="$(swift build --disable-sandbox --show-bin-path)"
"$BIN/CodexNotchCoreTests"

# Exercise the actual background watcher and view model in an isolated Codex home.
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-notch-watcher.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -I "$BIN/Modules" "$BIN"/CodexNotchCore.build/*.swift.o \
  "$ROOT/Sources/CodexNotch/RolloutWatcher.swift" \
  "$ROOT/Sources/CodexNotch/EventInbox.swift" \
  "$ROOT/Sources/CodexNotch/IslandViewModel.swift" \
  "$ROOT/Tests/WatcherIntegration/main.swift" -o "$TEST_DIR/watcher-tests"
"$TEST_DIR/watcher-tests" "$TEST_DIR/codex-home"
