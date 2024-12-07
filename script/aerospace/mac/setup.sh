#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"

AEROSPACE_PATH="$HOME/.aerospace.toml"
AEROSPACE_SYMLINK_TARGET="$SCRIPT_DIR/../../../configs/aerospace/.aerospace.toml"

SKETCHYBAR_PATH="$HOME/.config/sketchybar/sketchybarrc"
SKETCHYBAR_SYMLINK_TARGET="$SCRIPT_DIR/../../../configs/aerospace/sketchybarrc"

if [ -f "$AEROSPACE_PATH" ]; then
	fail "Identified .aerospce.toml exists. please delete manually"
else
	# Create a symlink if .aerospace.toml doesn't exist
	ln -s "$AEROSPACE_SYMLINK_TARGET" "$AEROSPACE_PATH"
	info "Symlink created for $AEROSPACE_PATH"
fi

if [ -f "$SKETCHYBAR_PATH" ]; then
	info "Identified sketchybarrc exists. please delete manually"
else
	# Create a symlink if .aerospace.toml doesn't exist
	ln -s "$SKETCHYBAR_SYMLINK_TARGET" "$SKETCHYBAR_PATH"
	info "Symlink created for $SKETCHYBAR_SYMLINK_TARGET"
fi

# allows to move windows by dragging any part of the window using Ctrl + Cmd
defaults write -g NSWindowShouldDragOnGesture -bool tre

# dusabbles windows opening animations
defaults write -g NSAutomaticWindowAnimationsEnabled -bool false
