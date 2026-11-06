#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .tools
archive=".tools/godotsteam-macos.tar.xz"
url="https://github.com/GodotSteam/GodotSteam/releases/download/v4.23.2/macos-g472-s165-gs4232-editor.tar.xz"
digest="5d4995e60851fba3d0a9f7a8fac82e515a53af46f0c43e6e6f1a0586e023b633"
if ! printf '%s  %s\n' "$digest" "$archive" | shasum -a 256 -c - >/dev/null 2>&1; then
    curl -fL --retry 2 "$url" -o "$archive"
fi
printf '%s  %s\n' "$digest" "$archive" | shasum -a 256 -c -
mkdir -p .tools/godotsteam
tar -xf "$archive" -C .tools/godotsteam
printf '\nInstalled locally. Run ./play.command\n'
