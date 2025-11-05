#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

if command -v opencode &>/dev/null; then
	debug "OpenCode.ai is already installed, skipping installation..."
else
	info "Installing OpenCode.ai..."
	curl -fsSL https://opencode.ai/install | bash
	success "OpenCode.ai installation completed!"
fi

mkdir -p "$HOME/.config/opencode"
link_file "$SCRIPT_DIR/../../configs/opencode/opencode.json" "$HOME/.config/opencode/opencode.json"
