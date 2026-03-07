#!/bin/bash
set -euo pipefail
# Start AirVPN via NetworkManager and enable CDN split-tunnel bypass

VPN_CONNECTION="${1:-AirVPN_Netherlands_UDP-443-Entry3}"
DOMAIN_FILE="${HOME}/.config/vpn-split/exclude-domains.txt"

echo "── Starting VPN split tunnel ──"

# 1. Load nftables CDN bypass rules (idempotent)
if ! sudo nft list table ip vpn_split &>/dev/null; then
    echo "Loading nftables CDN bypass rules..."
    sudo nft -f /etc/nftables.d/cdn-bypass.nft
fi

# 2. Add routing rule: marked packets (0x2) go direct, not through VPN
if ! ip rule show | grep -q "fwmark 0x2"; then
    sudo ip rule add fwmark 0x2 table main priority 100
    echo "Added bypass routing rule (fwmark 0x2 → table main)"
fi

# 3. Bring up VPN via NetworkManager
echo "Connecting: ${VPN_CONNECTION}..."
nmcli connection up "${VPN_CONNECTION}"

# 4. Ensure /etc/resolv.conf points to dnsmasq so DNS queries go through it
if ! grep -q "^nameserver 127.0.0.1" /etc/resolv.conf 2>/dev/null; then
    echo "Pointing DNS at dnsmasq (127.0.0.1)..."
    sudo rm -f /etc/resolv.conf
    echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf >/dev/null
fi

# 5. Start dnsmasq if not running (populates the nftables CDN set on DNS queries)
if ! systemctl is-active --quiet dnsmasq; then
    sudo systemctl start dnsmasq
fi

echo ""
echo "VPN is UP — CDN traffic routes directly, everything else through VPN"
echo "  Connection: ${VPN_CONNECTION}"
echo "  Excluded domains: $(grep -cv '^\s*#\|^\s*$' "$DOMAIN_FILE" 2>/dev/null || echo 0)"
echo "  Check status: vpn-status"
echo "  Stop: vpn-down"
