#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

# Rift config
RIFT_SOURCE="$SCRIPT_DIR/../../../configs/rift/config.toml"
RIFT_TARGET="$HOME/.config/rift/config.toml"

mkdir -p "$HOME/.config/rift"
link_file "$RIFT_SOURCE" "$RIFT_TARGET"

# Sketchybar config
SKETCHYBAR_SOURCE="$SCRIPT_DIR/../../../configs/rift/sketchybar"
SKETCHYBAR_TARGET="$HOME/.config/sketchybar"

link_file "$SKETCHYBAR_SOURCE" "$SKETCHYBAR_TARGET"

# Seed the active-theme symlink (machine-local, gitignored — switched later
# via switch-theme.sh). helpers/init.lua falls back to nest without it, but
# seeding keeps switch-theme.sh's "current theme" display accurate.
if [ ! -e "$SKETCHYBAR_SOURCE/themes/active" ]; then
    step "Setting default sketchybar theme (nest)..."
    ln -s nest "$SKETCHYBAR_SOURCE/themes/active"
fi

# Borders (JankyBorders) — active-window highlight
# Bare `borders` sources ~/.config/borders/bordersrc, so the symlink must
# point at the rift copy (the old aerospace one left a dangling link).
BORDERS_SOURCE="$SCRIPT_DIR/../../../configs/rift/bordersrc"
BORDERS_TARGET="$HOME/.config/borders/bordersrc"

mkdir -p "$HOME/.config/borders"
link_file "$BORDERS_SOURCE" "$BORDERS_TARGET"

# Run under brew services: KeepAlive restarts borders if it dies, and the
# appearance watcher relies on this — it only kills borders and lets
# launchd relaunch it with the new appearance colors.
if ! brew services list | grep -Eq '^borders\s+started'; then
    step "Starting borders service..."
    brew services start borders
fi

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

# Run rift under brew services (homebrew.mxcl.rift) — consistent with
# sketchybar/borders supervision on this machine. Do NOT use the native
# `rift service install` (git.acsandmann.rift): having both plists in
# ~/Library/LaunchAgents risks duplicate instances at login.
RIFT_NATIVE_PLIST="$HOME/Library/LaunchAgents/git.acsandmann.rift.plist"
if [ -f "$RIFT_NATIVE_PLIST" ]; then
    step "Removing stale native rift service plist..."
    launchctl bootout "gui/$(id -u)/git.acsandmann.rift" 2>/dev/null || true
    rm "$RIFT_NATIVE_PLIST"
fi

if brew services list | grep -Eq '^rift\s+started'; then
    brew services restart rift
else
    # The agent can be loaded outside brew's bookkeeping (status "other",
    # e.g. after a manual launchctl load or an interrupted brew run). In that
    # state `launchctl bootstrap` fails with EIO 5 — boot it out first.
    launchctl bootout "gui/$(id -u)/homebrew.mxcl.rift" 2>/dev/null || true
    brew services start rift
fi
success "rift service started"

# NOTE: WM-related global defaults (dock/menu bar autohide, window drag
# gesture, desktop icons, killall) live in script/macos/setup.sh.

# macOS bug: Accessibility permissions require dragging the real binary (not symlink)
RIFT_BIN=$(realpath "$(command -v rift)")
info "Drag rift into the Accessibility pane opening now:"
info "  $RIFT_BIN"
open -R "$RIFT_BIN"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
