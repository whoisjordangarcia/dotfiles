#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

# Managed Brave policies (force-installed extensions, disabled built-in
# password manager, forced search engine, blocked sign-in) are OPT-IN.
# They are intended for fresh/work machines and will clobber a personal
# Brave profile: saved logins get hidden, you get signed out, and your
# extensions become enterprise-managed. To apply them, set
# DOT_BRAVE_MANAGED=1; otherwise this component is a no-op.
if [[ "${DOT_BRAVE_MANAGED:-0}" != "1" ]]; then
    info "Brave managed policies are opt-in (set DOT_BRAVE_MANAGED=1 to apply). Skipping."
    exit 0
fi

# Brave policy directory on Linux (user-level)
BRAVE_POLICY_DIR="$HOME/.config/BraveSoftware/Brave-Browser/policies/managed"

# Check if Brave is installed
if ! command -v brave-browser &>/dev/null && ! command -v brave &>/dev/null; then
    info "Brave Browser not found."
    info "Install instructions:"
    info "  Ubuntu/Debian: https://brave.com/linux/#debian-ubuntu-mint"
    info "  Fedora: https://brave.com/linux/#fedora-centos-streamrhel"
    info "  Arch: pacman -S brave-bin (AUR)"
    info "Skipping Brave policy setup..."
    exit 0
fi

# Create policy directory if it doesn't exist
if [ ! -d "$BRAVE_POLICY_DIR" ]; then
    info "Creating Brave policies directory..."
    mkdir -p "$BRAVE_POLICY_DIR"
fi

# Symlink policies.json
step "Linking Brave managed policies..."
link_file "$SCRIPT_DIR/../../../configs/brave/policies/managed/policies.json" "$BRAVE_POLICY_DIR/policies.json"

success "Brave policies configured!"
info "Restart Brave Browser for policies to take effect."
info "Extensions will be installed automatically on next launch."
