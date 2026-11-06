#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [ -n "${GODOT_BIN:-}" ]; then
    engine="$GODOT_BIN"
else
    engine=$(find "$PWD/.tools/godotsteam" -type f -path '*/Contents/MacOS/*' ! -name '*.dylib' -perm -111 2>/dev/null | head -n 1 || true)
fi
if [ -z "$engine" ]; then
    printf 'Local GodotSteam not found. Run bash scripts/setup-macos.sh first.\n'
    exit 1
fi
exec "$engine" --path "$PWD" "$@"
