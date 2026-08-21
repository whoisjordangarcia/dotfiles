#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"

PLIST_NAME="com.nest.sd-backup"
CONFIG_DIR="$SCRIPT_DIR/../../../configs/sd-backup"
PLIST_SOURCE="$CONFIG_DIR/$PLIST_NAME.plist"
PLIST_TARGET="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

chmod +x "$CONFIG_DIR/sd-backup.sh"

# --- SDBackup.app -----------------------------------------------------------
#
# macOS TCC refuses a launchd agent access to removable volumes and never
# prompts for it (background jobs have no UI context), so the agent can detect
# a card but not read it. An app bundle DOES get a TCC identity, and child
# processes inherit the identity of the app responsible for them — so the agent
# hands the work to this applet, which re-enters the script with --run.
#
# osacompile emits a real signed bundle without Xcode; the only thing it omits
# is a bundle identifier, which is exactly what TCC keys on.
APP="$HOME/Applications/SDBackup.app"
APP_ID="dev.jordan.sd-backup"
BACKUP_SH="$(cd "$CONFIG_DIR" && pwd)/sd-backup.sh"

step "Building SDBackup.app..."
mkdir -p "$HOME/Applications"
rm -rf "$APP"
# `with timeout` because a first import can be several GB over SMB and the
# default Apple Event timeout would abandon it mid-copy.
osacompile -o "$APP" -e "with timeout of 86400 seconds
    do shell script \"'$BACKUP_SH' --run\"
end timeout" 2>/dev/null

/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $APP_ID" \
    "$APP/Contents/Info.plist" 2>/dev/null ||
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $APP_ID" \
        "$APP/Contents/Info.plist"
# Background agent: no Dock icon, no menu bar.
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" \
    "$APP/Contents/Info.plist" 2>/dev/null || true
codesign --force --deep -s - "$APP" 2>/dev/null

success "SDBackup.app built ($APP_ID)"

# Unload existing agent if loaded (modern bootout/bootstrap API —
# launchctl load/unload are deprecated)
if launchctl print "gui/$(id -u)/$PLIST_NAME" &>/dev/null; then
    step "Unloading existing SD card backup agent..."
    launchctl bootout "gui/$(id -u)/$PLIST_NAME" 2>/dev/null || true
fi

# Install plist
step "Installing SD card backup launchd agent..."
cp "$PLIST_SOURCE" "$PLIST_TARGET"

# Load agent
launchctl bootstrap "gui/$(id -u)" "$PLIST_TARGET"
success "SD card backup installed — insert a card to be prompted"

# The agent mounts the NAS itself, and launchd gives it a minimal environment,
# so it reads the share URL out of ~/.zshrc-sec rather than inheriting it.
if ! grep -q "NAS_SMB_URL" "$HOME/.zshrc-sec" 2>/dev/null; then
    info 'Set NAS_SMB_URL in ~/.zshrc-sec for the backup to reach tank01:'
    info '  export NAS_SMB_URL="smb://user@host/tank01"'
fi

info "Log: /tmp/sd-backup.log"
