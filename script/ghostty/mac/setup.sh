#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

GHOSTTY_SOURCE="$SCRIPT_DIR/../../configs/ghostty/config"
GHOSTTY_TARGET="$HOME/Library/Application Support/com.mitchellh.ghostty/config"

link_file "$GHOSTTY_SOURCE" "$GHOSTTY_TARGET"
