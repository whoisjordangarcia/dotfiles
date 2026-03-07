#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

SUNSHINE_CONFIG_DIR="$HOME/.config/sunshine"
CONFIGS_DIR="$SCRIPT_DIR/../../../configs/sunshine"

# Install sunshine-beta via Homebrew
info "Installing Sunshine beta..."
brew install lizardbyte/homebrew/sunshine-beta

# Create config directory if it doesn't exist
mkdir -p "$SUNSHINE_CONFIG_DIR"

# Symlink config files
link_file "$CONFIGS_DIR/apps.json" "$SUNSHINE_CONFIG_DIR/apps.json"
link_file "$CONFIGS_DIR/sunshine.conf" "$SUNSHINE_CONFIG_DIR/sunshine.conf"

# Note: Use the clamshell alias to prevent sleep when streaming
# Don't set it automatically — laptop should still sleep when closed normally

# Start sunshine-beta service
brew services start sunshine-beta

success "Sunshine beta configured! Power management set to prevent sleep."
info "Access Sunshine web UI at https://localhost:47990"

# macOS permissions required (must be granted manually):
#   - Screen Recording: allows Sunshine to capture the display
#   - Accessibility: allows Sunshine to inject keyboard and mouse input (clicks, keypresses)
# Both are in System Settings → Privacy & Security
# The sunshine binary path must be added to each:
#   $(readlink -f /opt/homebrew/opt/sunshine-beta/bin/sunshine)
# Permissions must be re-granted after each Sunshine update (new binary path).
warn "MANUAL STEP: Grant macOS permissions to the sunshine binary:"
warn "  System Settings → Privacy & Security → Screen Recording (capture display)"
warn "  System Settings → Privacy & Security → Accessibility (keyboard & mouse input)"
SUNSHINE_BIN=$(readlink -f /opt/homebrew/opt/sunshine-beta/bin/sunshine 2>/dev/null || echo "/opt/homebrew/opt/sunshine-beta/bin/sunshine")
warn "  Binary path: $SUNSHINE_BIN"
