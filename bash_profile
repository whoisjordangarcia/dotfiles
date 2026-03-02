# .bash_profile - Login Shell Config

[[ -f "$HOME/.bashrc" ]] && source "$HOME/.bashrc"

# SSH agent
[[ -z "$SSH_AUTH_SOCK" ]] && command -v ssh-agent &>/dev/null && eval "$(ssh-agent -s)" &>/dev/null

# Add keys
[[ -f "$HOME/.ssh/id_rsa" ]] && ssh-add "$HOME/.ssh/id_rsa" 2>/dev/null || true
[[ -f "$HOME/.ssh/id_ed25519" ]] && ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null || true

# Paths
[[ -d /usr/local/go/bin ]] && export PATH="$PATH:/usr/local/go/bin"
[[ -d "$HOME/.cargo/bin" ]] && export PATH="$PATH:$HOME/.cargo/bin"
[[ -d "$HOME/.local/share/pnpm" ]] && export PATH="$PATH:$HOME/.local/share/pnpm"

# Locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# Proxmox path
[[ -f /etc/pve/proxmox-release ]] && export PATH="$PATH:/usr/share/pve-manager/bin"

# Health checks (root)
if [[ $EUID -eq 0 ]]; then
    DISK_USAGE=$(df / 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%')
    [[ -n "$DISK_USAGE" ]] && [[ "$DISK_USAGE" -gt 90 ]] && echo "⚠️  Disk ${DISK_USAGE}% full!"
    [[ -f /var/run/reboot-required ]] && echo "🔄 REBOOT REQUIRED"
fi