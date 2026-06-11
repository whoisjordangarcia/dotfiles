#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/common/log.sh"
source "$SCRIPT_DIR/common/check_ssh.sh"
source "$SCRIPT_DIR/common/run_components.sh"

# Set work environment (exported so child component scripts see it)
export WORK_ENV="1"
export DOT_ENVIRONMENT="work"
debug "Work installation - enabling work-specific configurations"

# Must come after WORK_ENV is set — the component list is environment-aware
source "$SCRIPT_DIR/mac_components.sh"

section "Preflight checks"
check_github_ssh

run_components "${component_installation[@]}"

header "Installation Complete"
success "All components installed successfully!"
info "Restart your terminal or run: source ~/.zshrc"
