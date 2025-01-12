#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

HYPR_SOURCE="$SCRIPT_DIR/../../configs/hypr/hyprland.conf"
HYPR_TARGET="$HOME/.config/hypr/hyprland.conf"

if [ ! -f "$HOME/.config/hypr/" ]; then
	mkdir -p "$HOME/.config/hypr/"
fi

link_file "$HYPR_SOURCE" "$HYPR_TARGET"
