#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

CONFIGS="$SCRIPT_DIR/../../../configs"

# GTK 3.0
mkdir -p "$HOME/.config/gtk-3.0/"
link_file "$CONFIGS/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"

# GTK 4.0
mkdir -p "$HOME/.config/gtk-4.0/"
link_file "$CONFIGS/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"

# Kvantum (Qt styling engine)
mkdir -p "$HOME/.config/Kvantum/"
link_file "$CONFIGS/kvantum/kvantum.kvconfig" "$HOME/.config/Kvantum/kvantum.kvconfig"

# Qt6ct (Qt6 configuration tool)
mkdir -p "$HOME/.config/qt6ct/"
link_file "$CONFIGS/qt6ct/qt6ct.conf" "$HOME/.config/qt6ct/qt6ct.conf"

# Force GTK theme via gsettings (overrides HyDE wallbash auto-theming)
if command -v gsettings &>/dev/null; then
	gsettings set org.gnome.desktop.interface gtk-theme 'Gruvbox-Retro'
	success "Set gsettings GTK theme to Gruvbox-Retro"
fi
