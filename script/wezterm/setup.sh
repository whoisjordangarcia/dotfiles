#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"

WEZTERM_PATH="$HOME/.wezterm.lua"
WEZTERM_SYMLINK_TARGET="$SCRIPT_DIR/../../configs/wezterm/.wezterm.lua"

info "Deleting file $WEZTERM_PATH"
rm "$WEZTERM_PATH"

ln -s "$WEZTERM_SYMLINK_TARGET" "$WEZTERM_PATH"
info "Symlink created for $WEZTERM_PATH"
