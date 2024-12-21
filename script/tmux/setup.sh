#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

TMUX_SOURCE="$SCRIPT_DIR/../../configs/tmux/.tmux.conf"
TMUX_TARGET="$HOME/.tmux.conf"

link_file "$TMUX_SOURCE" "$TMUX_TARGET"

TPM_DIR="$HOME/.tmux/plugins/tpm"

if [ -d "$TPM_DIR" ]; then
	info "TPM is already installed at $TPM_DIR."
else
	info "TPM not found. Installing..."
	git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
	info "TPM successfully installed."
fi
