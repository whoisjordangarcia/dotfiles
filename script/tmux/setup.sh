#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

TMUX_SOURCE="$SCRIPT_DIR/../../configs/tmux/.tmux.conf"
TMUX_TARGET="$HOME/.tmux.conf"

link_file "$TMUX_SOURCE" "$TMUX_TARGET"

# Link tmux statusline scripts
TMUX_SCRIPTS_SOURCE="$SCRIPT_DIR/../../configs/tmux/scripts"
TMUX_SCRIPTS_TARGET="$HOME/.tmux/scripts"

if [ -d "$TMUX_SCRIPTS_SOURCE" ]; then
	info "Linking tmux statusline scripts directory..."
	# Create .tmux directory if it doesn't exist
	mkdir -p "$HOME/.tmux"
	link_file "$TMUX_SCRIPTS_SOURCE" "$TMUX_SCRIPTS_TARGET"
else
	error "Tmux scripts source directory not found at $TMUX_SCRIPTS_SOURCE"
fi

TPM_DIR="$HOME/.tmux/plugins/tpm"

if [ -d "$TPM_DIR" ]; then
	debug "TPM is already installed at $TPM_DIR."
else
	info "TPM not found. Installing..."
	git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
	info "TPM successfully installed."
fi
