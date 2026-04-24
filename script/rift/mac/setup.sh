#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

# Rift config
RIFT_SOURCE="$SCRIPT_DIR/../../configs/rift/config.toml"
RIFT_TARGET="$HOME/.config/rift/config.toml"

mkdir -p "$HOME/.config/rift"
link_file "$RIFT_SOURCE" "$RIFT_TARGET"

# Sketchybar config
SKETCHYBAR_SOURCE="$SCRIPT_DIR/../../configs/rift/sketchybar"
SKETCHYBAR_TARGET="$HOME/.config/sketchybar"

link_file "$SKETCHYBAR_SOURCE" "$SKETCHYBAR_TARGET"

# SbarLua
if [ ! -d "$HOME/.local/share/sketchybar_lua" ]; then
    step "Installing SbarLua..."
    (git clone https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua && cd /tmp/SbarLua/ && make install && rm -rf /tmp/SbarLua/)
    success "SbarLua installed"
else
    debug "SbarLua already installed, skipping"
fi

# Fonts
if [[ ! -f "$HOME/Library/Fonts/sketchybar-app-font.ttf" ]]; then
    step "Downloading sketchybar-app-font..."
    curl -L "https://github.com/kvndrsslr/sketchybar-app-font/releases/download/v2.0.28/sketchybar-app-font.ttf" -o "$HOME/Library/Fonts/sketchybar-app-font.ttf"
    success "sketchybar-app-font installed"
else
    debug "sketchybar-app-font already installed, skipping"
fi

# Install and start rift service
RIFT_PLIST="$HOME/Library/LaunchAgents/git.acsandmann.rift.plist"
if [ ! -f "$RIFT_PLIST" ]; then
    step "Installing rift service..."
    rift service install
else
    debug "rift service already installed, skipping"
fi

# `restart` uses `launchctl kickstart -k` which requires the service to
# already be bootstrapped in the user domain. If the plist exists but the
# service isn't loaded (e.g. after a reboot or manual bootout), use `start`
# to bootstrap it instead.
if launchctl print "gui/$(id -u)/git.acsandmann.rift" &>/dev/null; then
    rift service restart
else
    rift service start
fi
success "rift service started"

# allows to move windows by dragging any part of the window using Ctrl + Cmd
defaults write -g NSWindowShouldDragOnGesture -bool true

# disable windows opening animations
defaults write -g NSAutomaticWindowAnimationsEnabled -bool false

# autohide dock
defaults write com.apple.dock autohide -bool true

# autohide status bar
defaults write NSGlobalDomain _HIHideMenuBar -bool true

# hide desktop icons
defaults write com.apple.finder CreateDesktop -bool false

killall Dock
killall SystemUIServer
killall Finder

# macOS bug: Accessibility permissions require dragging the real binary (not symlink)
# Must run AFTER killall Finder so the window stays open
RIFT_BIN=$(realpath "$(command -v rift)")
info "Drag rift into the Accessibility pane opening now:"
info "  $RIFT_BIN"
open -R "$RIFT_BIN"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
