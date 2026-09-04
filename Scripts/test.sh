#!/bin/bash

set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
binary_dir="$project_dir/.build/manual"
test_binary="$binary_dir/CodexPulseSmokeTests"
overlay_path="$project_dir/Support/swift-module-overlay.json"
target_arch="$(uname -m)"

mkdir -p "$binary_dir"

if swift package --package-path "$project_dir" dump-package >/dev/null 2>&1; then
    swift test --package-path "$project_dir"
    exit 0
fi

swiftc \
    -O \
    -target "${target_arch}-apple-macos13.0" \
    -Xfrontend -vfsoverlay \
    -Xfrontend "$overlay_path" \
    "$project_dir/AppSources/CodexPulse/Models/QuotaSnapshot.swift" \
    "$project_dir/AppSources/CodexPulse/Services/CodexActivityDetector.swift" \
    "$project_dir/AppSources/CodexPulse/Services/QuotaProvider.swift" \
    "$project_dir/Tests/SmokeTests/main.swift" \
    -framework AppKit \
    -o "$test_binary"

"$test_binary"
