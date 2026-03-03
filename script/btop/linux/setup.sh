#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

mkdir -p "$HOME/.config/btop/"

link_file "$SCRIPT_DIR/../../configs/btop/btop.conf" "$HOME/.config/btop/btop.conf"
