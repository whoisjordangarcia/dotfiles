#!/bin/bash
#===============================================================================
# Dotfiles Setup Script
# Usage: bash setup.sh
#===============================================================================

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

log "Dotfiles Setup Script"
echo ""

# Detect environment
IS_PROXMOX=false
[[ -f /etc/pve/proxmox-release ]] && IS_PROXMOX=true

IS_DOCKER=false
[[ -f /.dockerenv ]] && IS_DOCKER=true

mkdir -p "$BACKUP_DIR"

# Backup
backup_if_exists() {
    local file="$1"
    if [[ -f "$file" && ! -L "$file" ]]; then
        cp "$file" "$BACKUP_DIR/"
        success "Backed up $(basename "$file")"
    fi
}

log "Backing up existing dotfiles..."
backup_if_exists "$HOME/.bashrc"
backup_if_exists "$HOME/.bash_profile"
backup_if_exists "$HOME/.bash_aliases"
backup_if_exists "$HOME/.tmux.conf"
backup_if_exists "$HOME/.gitconfig"

# Install
log "Installing dotfiles..."
mkdir -p "$HOME/.config/bash/functions"

ln -sf "$DOTFILES_DIR/bashrc" "$HOME/.bashrc" 2>/dev/null && success ".bashrc linked"
ln -sf "$DOTFILES_DIR/bash_profile" "$HOME/.bash_profile" 2>/dev/null && success ".bash_profile linked"
ln -sf "$DOTFILES_DIR/aliases" "$HOME/.bash_aliases" 2>/dev/null && success ".bash_aliases linked"
ln -sf "$DOTFILES_DIR/functions/"*.sh "$HOME/.config/bash/functions/" 2>/dev/null && success "Functions linked"
ln -sf "$DOTFILES_DIR/tmux.conf" "$HOME/.tmux.conf" 2>/dev/null && success ".tmux.conf linked"

# Logging
mkdir -p "$HOME/.logs/bash"
touch "$HOME/.logs/bash/commands.log"
chmod 750 "$HOME/.logs" "$HOME/.logs/bash"
chmod 600 "$HOME/.logs/bash/"*.log 2>/dev/null

# SSH hardening check (if root)
if [[ $EUID -eq 0 ]] && [[ -f /etc/ssh/sshd_config ]]; then
    log "Checking SSH..."
    grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config && warning "Root login enabled - consider disabling"
    grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config && warning "Password auth enabled - consider key-only"
fi

echo ""
success "Setup complete! Run: source ~/.bashrc"
