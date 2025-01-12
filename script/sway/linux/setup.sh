#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

SWAY_SOURCE="$SCRIPT_DIR/../../../sway/config"
SWAY_TARGET="$HOME/.config/sway/config"

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

link_file "$SWAY_SOURCE" "$SWAY_TARGET"
