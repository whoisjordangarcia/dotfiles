#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

GHOSTTY_SOURCE="$SCRIPT_DIR/../../../configs/ghostty/config"
GHOSTTY_TARGET="$HOME/.config/ghostty/config"

if [ ! -f "$HOME/.config/ghostty" ]; then
	mkdir -p "$HOME/.config/ghostty"
fi

link_file "$GHOSTTY_SOURCE" "$GHOSTTY_TARGET"
# Ghostty resolves `config-file = ?platform-linux` next to the symlink, not next
# to the link's target, so the override has to be linked here too.
link_file "${GHOSTTY_SOURCE%/config}/platform-linux" "${GHOSTTY_TARGET%/config}/platform-linux"
