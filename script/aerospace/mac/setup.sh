#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

AEROSPACE_SOURCE="$SCRIPT_DIR/../../configs/aerospace/.aerospace.toml"
AEROSPACE_TARGET="$HOME/.aerospace.toml"

link_file "$AEROSPACE_SOURCE" "$AEROSPACE_TARGET"

SKETCHYBAR_SOURCE="$SCRIPT_DIR/../../configs/aerospace/sketchybar"
SKETCHYBAR_TARGET="$HOME/.config/sketchybar"

link_file "$SKETCHYBAR_SOURCE" "$SKETCHYBAR_TARGET"

# SbarLua
(git clone https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua && cd /tmp/SbarLua/ && make install && rm -rf /tmp/SbarLua/)

# Fonts
curl -L https://github.com/kvndrsslr/sketchybar-app-font/releases/download/v2.0.28/sketchybar-app-font.ttf -o $HOME/Library/Fonts/sketchybar-app-font.ttf

# allows to move windows by dragging any part of the window using Ctrl + Cmd
defaults write -g NSWindowShouldDragOnGesture -bool tre

# disable windows opening animations
defaults write -g NSAutomaticWindowAnimationsEnabled -bool false
