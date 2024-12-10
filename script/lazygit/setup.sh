#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"

LAZYGIT_PATH="$HOME/.config/lazygit/config.yml"
LAZYGIT_SYMLINK_TARGET="$SCRIPT_DIR/../../configs/lazygit/config.yml"

info "Deleting file $LAZYGIT_PATH"
rm "$LAZYGIT_PATH"

ln -s "$LAZYGIT_SYMLINK_TARGET" "$LAZYGIT_PATH"
info "Symlink created for $LAZYGIT_PATH"
