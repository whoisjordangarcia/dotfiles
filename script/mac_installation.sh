#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/common/log.sh"
source "$SCRIPT_DIR/common/check_ssh.sh"
source "$SCRIPT_DIR/common/run_components.sh"
source "$SCRIPT_DIR/mac_components.sh"

section "Preflight checks"
check_github_ssh

run_components "${component_installation[@]}"

header "Installation Complete"
success "All components installed successfully!"
info "Restart your terminal or run: source ~/.zshrc"
