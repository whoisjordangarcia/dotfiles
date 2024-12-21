#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

STARSHIP_SOURCE="$SCRIPT_DIR/../../configs/starship/starship.toml"
STARSHIP_TARGET="$HOME/.config/starship.toml"

link_file "$STARSHIP_SOURCE" "$STARSHIP_TARGET"
