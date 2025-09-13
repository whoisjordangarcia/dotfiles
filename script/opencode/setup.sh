#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"

info "Installing OpenCode.ai..."

# Run the official installation script
curl -fsSL https://opencode.ai/install | bash

success "OpenCode.ai installation completed!"
info "You may need to restart your terminal or run 'source ~/.bashrc' (or ~/.zshrc) to use the 'opencode' command."