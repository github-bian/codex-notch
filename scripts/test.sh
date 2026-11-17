#!/usr/bin/env bash
# Builds everything and runs the executable check suite (XCTest is not available
# with Command Line Tools alone).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

swift build --disable-sandbox
BIN="$(swift build --disable-sandbox --show-bin-path)"
"$BIN/CodexNotchCoreTests"
