#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"

PLIST_NAME="com.nest.appearance-watcher"
PLIST_SOURCE="$SCRIPT_DIR/../../../configs/rift/$PLIST_NAME.plist"
PLIST_TARGET="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

# Unload existing agent if loaded
if launchctl list | grep -q "$PLIST_NAME"; then
    step "Unloading existing appearance watcher..."
    launchctl unload "$PLIST_TARGET" 2>/dev/null || true
fi

# Install plist
step "Installing appearance watcher launchd agent..."
cp "$PLIST_SOURCE" "$PLIST_TARGET"

# Load agent
launchctl load "$PLIST_TARGET"
success "Appearance watcher installed and loaded"
