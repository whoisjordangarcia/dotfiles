#!/bin/bash
set -euo pipefail
# Stop AirVPN via NetworkManager and clean up split tunnel rules

VPN_CONNECTION="${1:-AirVPN_Netherlands_UDP-443-Entry3}"

echo "── Stopping VPN split tunnel ──"

# 1. Bring down VPN via NetworkManager
if nmcli connection show --active | grep -q "${VPN_CONNECTION}"; then
    echo "Disconnecting: ${VPN_CONNECTION}..."
    nmcli connection down "${VPN_CONNECTION}"
else
    echo "VPN connection '${VPN_CONNECTION}' not active"
fi

# 2. Remove bypass routing rule
if ip rule show | grep -q "fwmark 0x2"; then
    sudo ip rule del fwmark 0x2 table main priority 100
    echo "Removed bypass routing rule"
fi

# 3. Flush the nftables CDN bypass sets
sudo nft flush set ip vpn_split cdn_bypass 2>/dev/null && echo "Flushed IPv4 bypass set"
sudo nft flush set ip6 vpn_split cdn_bypass6 2>/dev/null && echo "Flushed IPv6 bypass set"
sudo nft delete table ip vpn_split 2>/dev/null || true
sudo nft delete table ip6 vpn_split 2>/dev/null || true

echo ""
echo "VPN is DOWN — all traffic routing directly"
