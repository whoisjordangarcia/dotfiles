#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

DOLPHIN_SOURCE="$SCRIPT_DIR/../../../configs/dolphin/dolphinrc"
DOLPHIN_TARGET="$HOME/.config/dolphinrc"

link_file "$DOLPHIN_SOURCE" "$DOLPHIN_TARGET"
