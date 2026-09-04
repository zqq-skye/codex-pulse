#!/bin/bash

set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
app_dir="$project_dir/.build/Codex Pulse.app"
contents_dir="$app_dir/Contents"
macos_dir="$contents_dir/MacOS"
resources_dir="$contents_dir/Resources"

cd "$project_dir"
binary_path="$("$project_dir/Scripts/build-binary.sh")"
rm -rf "$app_dir"
mkdir -p "$macos_dir" "$resources_dir"
cp "$binary_path" "$macos_dir/CodexPulse"
cp "$project_dir/Support/Info.plist" "$contents_dir/Info.plist"
cp "$project_dir/Assets/AppIcon.icns" "$resources_dir/AppIcon.icns"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - "$app_dir"
fi

echo "$app_dir"
