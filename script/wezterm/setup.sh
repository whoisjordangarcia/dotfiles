#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

WEZTERM_SOURCE="$SCRIPT_DIR/../../configs/wezterm/.wezterm.lua"
WEZTERM_TARGET="$HOME/.wezterm.lua"

link_file "$WEZTERM_SOURCE" "$WEZTERM_TARGET"
