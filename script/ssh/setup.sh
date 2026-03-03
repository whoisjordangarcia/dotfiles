#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
DOTFILES_ROOT=$(cd -- "$SCRIPT_DIR/../.." &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

# Ensure ~/.ssh exists with correct permissions
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Create sockets directory for ControlMaster multiplexing
mkdir -p "$HOME/.ssh/sockets"

# Symlink the base SSH config (contains Include + global defaults)
link_file "$DOTFILES_ROOT/configs/ssh/config" "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config" 2>/dev/null || true

# Create hosts.local if it doesn't exist (machine-specific, not in git)
if [[ ! -f "$HOME/.ssh/hosts.local" ]]; then
	cat > "$HOME/.ssh/hosts.local" <<'EOF'
# Machine-specific SSH host aliases (not tracked in git)
#
# Example:
#   Host proxmox
#       HostName 192.168.1.100
#       User root
#
#   Host lxc-media
#       HostName 192.168.1.201
#       User jordan
#       ProxyJump proxmox
EOF
	chmod 600 "$HOME/.ssh/hosts.local"
	info "Created ~/.ssh/hosts.local — add your host aliases there"
else
	info "~/.ssh/hosts.local already exists, keeping your hosts"
fi
