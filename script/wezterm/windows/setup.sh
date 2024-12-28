#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

WINDOWS_PATH="/mnt/c/Users/jordan"

WEZTERM_SOURCE="$SCRIPT_DIR/../../configs/wezterm/.wezterm-win.lua"
WEZTERM_TARGET="$WINDOWS_PATH/.wezterm.lua"

rm -f "$WEZTERM_TARGET"
cp -fv "$WEZTERM_SOURCE" "$WEZTERM_TARGET"
