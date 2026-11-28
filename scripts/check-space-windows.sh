#!/usr/bin/env bash
# Builds and runs the self-check for Sources/SpaceWindows.swift.
set -euo pipefail
cd "$(dirname "$0")/.."
out="$(mktemp -d)/check-space-windows"
swiftc Sources/SpaceWindows.swift scripts/check-space-windows/main.swift -o "$out"
"$out"
