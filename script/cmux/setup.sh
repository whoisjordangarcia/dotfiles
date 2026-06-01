#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

# cmux is a macOS-only terminal. It reads settings from ~/.config/cmux and also
# inherits terminal appearance from the Ghostty config (handled by script/ghostty).
CMUX_CONFIG_DIR="$HOME/.config/cmux"
mkdir -p "$CMUX_CONFIG_DIR"

# Settings: actions, shortcut chords, automation, sidebar.
link_file "$SCRIPT_DIR/../../configs/cmux/cmux.json" "$CMUX_CONFIG_DIR/cmux.json"
