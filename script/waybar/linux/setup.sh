#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

WAYBAR_SOURCE="$SCRIPT_DIR/../../configs/waybar"
WAYBAR_TARGET="$HOME/.config/waybar"

if [ ! -f "$HOME/.config/waybar" ]; then
	mkdir -p "$HOME/.config/waybar"
fi

link_file "$WAYBAR_SOURCE" "$WAYBAR_TARGET"
