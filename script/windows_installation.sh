#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/common/log.sh"
source "$SCRIPT_DIR/common/run_components.sh"
source "$SCRIPT_DIR/windows_components.sh"

# Native symlinks (MSYS/CYGWIN=winsymlinks:nativestrict) are exported by script/common/symlink.sh.

run_components "${component_installation[@]}"

header "Installation Complete"
success "All components installed successfully!"
