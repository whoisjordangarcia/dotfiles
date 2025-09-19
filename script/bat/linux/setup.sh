#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
DOTFILES_DIR=$(cd "$SCRIPT_DIR/../../.." && pwd)

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

# Ensure bat config directory exists
BAT_CONFIG_DIR="$HOME/.config/bat"
mkdir -p "$BAT_CONFIG_DIR"

# Symlink primary config
BAT_CONFIG_SOURCE="$DOTFILES_DIR/configs/bat/config"
BAT_CONFIG_TARGET="$BAT_CONFIG_DIR/config"

if [ -f "$BAT_CONFIG_SOURCE" ]; then
	link_file "$BAT_CONFIG_SOURCE" "$BAT_CONFIG_TARGET"
else
	info "No bat config found at $BAT_CONFIG_SOURCE. Skipping config link."
fi

# Optional: link themes directory if provided in configs
BAT_THEMES_SOURCE_DIR="$DOTFILES_DIR/configs/bat/themes"
BAT_THEMES_TARGET_DIR="$BAT_CONFIG_DIR/themes"

if [ -d "$BAT_THEMES_SOURCE_DIR" ]; then
	link_file "$BAT_THEMES_SOURCE_DIR" "$BAT_THEMES_TARGET_DIR"
fi

# Debian/Ubuntu ship bat as 'batcat'. Provide a user-level shim if needed.
if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
	BIN_DIR="$HOME/.local/bin"
	mkdir -p "$BIN_DIR"
	link_file "/usr/bin/batcat" "$BIN_DIR/bat"
	info "Created user shim for bat at $BIN_DIR/bat (points to batcat). Ensure $BIN_DIR is in PATH."
fi

success "bat (Linux) setup complete."
