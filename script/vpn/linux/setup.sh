#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
CONFIGS_DIR="$SCRIPT_DIR/../../../configs/vpn-split"

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

# ── Verify dependencies (installed by apps/arch) ─────────────────────
command -v wg &>/dev/null || fail "wireguard-tools not installed — run apps/arch setup first"
command -v dnsmasq &>/dev/null || fail "dnsmasq not installed — run apps/arch setup first"

# ── Create local config directory ─────────────────────────────────────
LOCAL_CONFIG_DIR="$HOME/.config/vpn-split"
mkdir -p "$LOCAL_CONFIG_DIR"

# Seed default exclude list if one doesn't exist yet
if [ ! -f "$LOCAL_CONFIG_DIR/exclude-domains.txt" ]; then
    step "Creating default exclude-domains.txt"
    cp "$CONFIGS_DIR/exclude-domains.example.txt" "$LOCAL_CONFIG_DIR/exclude-domains.txt"
    info "Edit ~/.config/vpn-split/exclude-domains.txt to customize excluded domains"
fi

# ── Symlink helper scripts ────────────────────────────────────────────
RESOLVED_CONFIGS=$(realpath "$CONFIGS_DIR")

link_file "$RESOLVED_CONFIGS/vpn-up.sh" "$LOCAL_CONFIG_DIR/vpn-up.sh"
link_file "$RESOLVED_CONFIGS/vpn-down.sh" "$LOCAL_CONFIG_DIR/vpn-down.sh"
link_file "$RESOLVED_CONFIGS/vpn-gen-config.sh" "$LOCAL_CONFIG_DIR/vpn-gen-config.sh"

# ── Disable systemd-resolved stub so dnsmasq can bind port 53 ─────────
step "Configuring systemd-resolved to release port 53"
sudo mkdir -p /etc/systemd/resolved.conf.d
if [ ! -f /etc/systemd/resolved.conf.d/nostub.conf ]; then
    echo -e "[Resolve]\nDNSStubListener=no" | sudo tee /etc/systemd/resolved.conf.d/nostub.conf >/dev/null
    sudo systemctl restart systemd-resolved
fi

# ── Configure dnsmasq ─────────────────────────────────────────────────
step "Configuring dnsmasq for split-tunnel DNS"
sudo mkdir -p /etc/dnsmasq.d

# Generate initial dnsmasq config from exclude list
bash "$CONFIGS_DIR/vpn-gen-config.sh"

# Set dnsmasq to read conf-dir
if ! grep -q "^conf-dir=/etc/dnsmasq.d/,\*.conf" /etc/dnsmasq.conf 2>/dev/null; then
    echo "conf-dir=/etc/dnsmasq.d/,*.conf" | sudo tee -a /etc/dnsmasq.conf >/dev/null
fi

# Set upstream DNS servers for dnsmasq to forward to
if ! grep -q "^server=1.1.1.1" /etc/dnsmasq.conf 2>/dev/null; then
    printf "server=1.1.1.1\nserver=9.9.9.9\n" | sudo tee -a /etc/dnsmasq.conf >/dev/null
fi

# ── Configure nftables ────────────────────────────────────────────────
step "Installing nftables rules for CDN bypass"
sudo cp "$CONFIGS_DIR/cdn-bypass.nft" /etc/nftables.d/cdn-bypass.nft 2>/dev/null || {
    sudo mkdir -p /etc/nftables.d
    sudo cp "$CONFIGS_DIR/cdn-bypass.nft" /etc/nftables.d/cdn-bypass.nft
}

# ── Enable services ───────────────────────────────────────────────────
step "Enabling dnsmasq and nftables services"
sudo systemctl enable --now nftables
sudo systemctl enable dnsmasq

# ── Reminder ──────────────────────────────────────────────────────────
info ""
info "VPN split-tunnel setup complete!"
info ""
info "Next steps:"
info "  1. Generate a WireGuard config from https://airvpn.org/generator/"
info "  2. Save it to /etc/wireguard/airvpn.conf"
info "  3. Edit ~/.config/vpn-split/exclude-domains.txt to customize bypassed domains"
info "  4. Run: vpn-up   (starts VPN with CDN bypass)"
info "  5. Run: vpn-down (stops VPN and cleans up routes)"

success "VPN split-tunnel configured"
