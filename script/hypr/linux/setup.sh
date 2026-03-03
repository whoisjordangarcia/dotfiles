#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

HYPR_CONFIG="$SCRIPT_DIR/../../configs/hypr"

mkdir -p "$HOME/.config/hypr/"

# Core config files
link_file "$HYPR_CONFIG/hyprland.conf" "$HOME/.config/hypr/hyprland.conf"
link_file "$HYPR_CONFIG/keybindings.conf" "$HOME/.config/hypr/keybindings.conf"
link_file "$HYPR_CONFIG/userprefs.conf" "$HOME/.config/hypr/userprefs.conf"
link_file "$HYPR_CONFIG/windowrules.conf" "$HOME/.config/hypr/windowrules.conf"
link_file "$HYPR_CONFIG/hyde.conf" "$HOME/.config/hypr/hyde.conf"
link_file "$HYPR_CONFIG/nvidia.conf" "$HOME/.config/hypr/nvidia.conf"
link_file "$HYPR_CONFIG/pyprland.toml" "$HOME/.config/hypr/pyprland.toml"
