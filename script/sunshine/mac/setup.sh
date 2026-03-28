#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# Resolve CONFIGS_DIR before sourcing symlink.sh — sourcing it overwrites SCRIPT_DIR
# (symlink.sh sets SCRIPT_DIR=$(dirname ${BASH_SOURCE[0]}) which resolves to script/common)
SUNSHINE_CONFIG_DIR="$HOME/.config/sunshine"
CONFIGS_DIR="$SCRIPT_DIR/../../../configs/sunshine"

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

# Install sunshine-beta via Homebrew
info "Installing Sunshine beta..."
brew install lizardbyte/homebrew/sunshine-beta

# Create config directory if it doesn't exist
mkdir -p "$SUNSHINE_CONFIG_DIR"

# Symlink config files
link_file "$CONFIGS_DIR/apps.json" "$SUNSHINE_CONFIG_DIR/apps.json"
link_file "$CONFIGS_DIR/sunshine.conf" "$SUNSHINE_CONFIG_DIR/sunshine.conf"

SUNSHINE_BIN=$(readlink -f /opt/homebrew/opt/sunshine-beta/bin/sunshine 2>/dev/null || echo "/opt/homebrew/opt/sunshine-beta/bin/sunshine")
PLIST_SRC="/opt/homebrew/opt/sunshine-beta/homebrew.mxcl.sunshine-beta.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/homebrew.mxcl.sunshine-beta.plist"

# Install and start the LaunchAgent, triggering macOS TCC permission prompts.
#
# On macOS Sequoia, launchctl bootstrap exits 5 if Screen Recording / Accessibility
# haven't been granted yet, but it still registers the service in launchd.
# launchctl kickstart then attempts to actually run the binary, which causes macOS
# to fire the TCC permission dialogs automatically — no manual System Settings visit needed.
if [[ -f "$PLIST_SRC" ]]; then
  cp "$PLIST_SRC" "$PLIST_DEST"
  step "LaunchAgent plist installed"

  # Register the service (may exit non-zero on first run due to TCC — that's expected)
  launchctl bootstrap "gui/$UID" "$PLIST_DEST" 2>/dev/null || true

  # Kickstart triggers TCC prompts for Screen Recording + Accessibility
  step "Starting Sunshine (macOS will prompt for Screen Recording & Accessibility permissions)..."
  launchctl kickstart -p "gui/$UID/homebrew.mxcl.sunshine-beta" 2>/dev/null || \
    warn "Kickstart failed — if permissions were just granted, re-run: launchctl kickstart -p gui/$UID/homebrew.mxcl.sunshine-beta"
else
  warn "Plist not found at $PLIST_SRC — skipping LaunchAgent setup"
fi

success "Sunshine installed and configured."
info "Access Sunshine web UI at https://localhost:47990"
info "To stop:  launchctl kill TERM gui/$UID/homebrew.mxcl.sunshine-beta"
warn "NOTE: Re-run this script or kickstart manually after each Sunshine update (binary path changes)."
