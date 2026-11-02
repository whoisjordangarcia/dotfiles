#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/common/log.sh"
source "$SCRIPT_DIR/common/run_components.sh"
source "$SCRIPT_DIR/windows_components.sh"

# Real NTFS symlinks or a loud failure — never MSYS's default of silently copying
# files, which would break "edit the repo and the live config changes".
# Needs Windows Developer Mode (bootstrap.ps1 checks it before getting here).
export MSYS=winsymlinks:nativestrict

run_components "${component_installation[@]}"

header "Installation Complete"
success "All components installed successfully!"
