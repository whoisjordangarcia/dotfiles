#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

SUNSHINE_CONFIG_DIR="$HOME/.config/sunshine"
SUNSHINE_SOURCE="$SCRIPT_DIR/../../../configs/sunshine/apps.json"
SUNSHINE_TARGET="$SUNSHINE_CONFIG_DIR/apps.json"

# Create config directory if it doesn't exist
mkdir -p "$SUNSHINE_CONFIG_DIR"

# Symlink apps.json
link_file "$SUNSHINE_SOURCE" "$SUNSHINE_TARGET"

# Prevent sleep for game streaming (requires sudo)
info "Configuring power management for streaming..."
sudo pmset -a disablesleep 1
sudo pmset -a displaysleep 0
sudo pmset -a sleep 0

success "Sunshine configured! Power management set to prevent sleep."
info "Access Sunshine web UI at https://localhost:47990"
