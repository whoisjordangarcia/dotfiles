#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_DIR/../../common/log.sh"

section "UFW Firewall"

if ! command -v ufw &>/dev/null; then
    fail "ufw is not installed — install it via apps/arch first"
fi

step "Setting default policies (deny incoming, allow outgoing, drop forwarded)"
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw default deny forward

step "Allowing SSH with rate limiting (blocks brute force: 6+ connections/30s)"
sudo ufw limit ssh comment "SSH rate-limited"

step "Allowing Apollo/Sunshine streaming from LAN only (192.168.1.0/24)"
# Control + web UI
sudo ufw allow from 192.168.1.0/24 to any port 47984 proto tcp comment "Apollo HTTPS (LAN)"
sudo ufw allow from 192.168.1.0/24 to any port 47989 proto tcp comment "Apollo HTTP (LAN)"
sudo ufw allow from 192.168.1.0/24 to any port 47990 proto tcp comment "Apollo web UI (LAN)"
sudo ufw allow from 192.168.1.0/24 to any port 48010 proto tcp comment "Apollo RTSP (LAN)"
# Video/audio streams
sudo ufw allow from 192.168.1.0/24 to any port 47998:48000 proto udp comment "Apollo A/V streams (LAN)"

step "Allowing WireGuard VPN forwarding (required for split-tunnel)"
sudo ufw allow in on tun0
sudo ufw allow out on tun0

step "Enabling logging (low — logs blocked packets)"
sudo ufw logging low

step "Enabling UFW"
sudo ufw --force enable

step "Enabling ufw.service (persist across reboots)"
sudo systemctl enable --now ufw.service

success "UFW configured and enabled"
sudo ufw status verbose
