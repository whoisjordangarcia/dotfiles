#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

SUNSHINE_CONFIG_DIR="$HOME/.config/sunshine"
# macOS-specific config (the Linux/Arch config lives in ../linux and is used
# directly on that machine — the two OSes need different encoders/displays).
CONFIGS_DIR="$SCRIPT_DIR/../../../configs/sunshine/mac"

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

# Install sunshine-beta via Homebrew
info "Installing Sunshine beta..."
brew install lizardbyte/homebrew/sunshine-beta

# Create config directory if it doesn't exist
mkdir -p "$SUNSHINE_CONFIG_DIR"

# apps.json has no host-specific data → symlink it (edits sync back to the repo).
link_file "$CONFIGS_DIR/apps.json" "$SUNSHINE_CONFIG_DIR/apps.json"

# sunshine.conf embeds this host's LAN IP(s) in csrf_allowed_origins so the web
# UI doesn't 403 from other machines. It's GENERATED, not symlinked, so no real
# address is committed. Enumerate ALL private-range IPv4 addresses (a Mac can be
# multi-homed: Ethernet + Wi-Fi), so the origin check passes whichever IP the
# client reaches — DHCP/interface changes won't reintroduce the 403.
ORIGINS="https://localhost:47990"
for ip in $(ifconfig 2>/dev/null | awk '/inet /{print $2}' \
    | grep -E '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)'); do
  ORIGINS="$ORIGINS,https://$ip:47990"
done
info "Generating sunshine.conf with CSRF origins: $ORIGINS"
[ -L "$SUNSHINE_CONFIG_DIR/sunshine.conf" ] && rm -f "$SUNSHINE_CONFIG_DIR/sunshine.conf"
sed "s|^csrf_allowed_origins = .*|csrf_allowed_origins = $ORIGINS|" \
  "$CONFIGS_DIR/sunshine.conf" > "$SUNSHINE_CONFIG_DIR/sunshine.conf"

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
