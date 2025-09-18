#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

info "Ensuring $HOME/.config/fastfetch exists"
mkdir -p "$HOME/.config/fastfetch"

link_file "$SCRIPT_DIR/../configs/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
