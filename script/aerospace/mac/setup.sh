#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"

AEROSPACE_PATH="$HOME/.aerospace.toml"

AEROSPACE_SYMLINK_TARGET="$SCRIPT_DIR/../../../configs/aerospace/.aerospace.toml"

if [ -f "$AEROSPACE_PATH" ]; then
	info "Identified .aerospce.toml exists. please delete manually"
fi

# Create a symlink if .aerospace.toml doesn't exist
ln -s "$AEROSPACE_SYMLINK_TARGET" "$AEROSPACE_PATH"
info "Symlink created for $AEROSPACE_PATH"
