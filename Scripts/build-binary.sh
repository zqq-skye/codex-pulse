#!/bin/bash

set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
binary_dir="$project_dir/.build/manual"
binary_path="$binary_dir/CodexPulse"
overlay_path="$project_dir/Support/swift-module-overlay.json"
target_arch="$(uname -m)"
source_files=()

while IFS= read -r file; do
    source_files+=("$file")
done < <(find "$project_dir/AppSources/CodexPulse" -name '*.swift' -type f | sort)

mkdir -p "$binary_dir"
swiftc \
    -O \
    -whole-module-optimization \
    -target "${target_arch}-apple-macos13.0" \
    -Xfrontend -vfsoverlay \
    -Xfrontend "$overlay_path" \
    "${source_files[@]}" \
    -framework AppKit \
    -framework ServiceManagement \
    -o "$binary_path"

echo "$binary_path"
