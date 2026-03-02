#!/bin/bash
# Dotfiles Setup Script

set -e
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'

log() { echo -e "${BLUE}[DOTFILES]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

log "Installing dotfiles..."

# Backup
mkdir -p "$BACKUP_DIR"
[[ -f "$HOME/.bashrc" ]] && cp "$HOME/.bashrc" "$BACKUP_DIR/" && success "Backed up .bashrc"
[[ -f "$HOME/.bash_aliases" ]] && cp "$HOME/.bash_aliases" "$BACKUP_DIR/" && success "Backed up .bash_aliases"

# Link
mkdir -p "$HOME/.config/bash/functions"
ln -sf "$DOTFILES_DIR/bashrc" "$HOME/.bashrc" && success ".bashrc linked"
ln -sf "$DOTFILES_DIR/bash_profile" "$HOME/.bash_profile" && success ".bash_profile linked"
ln -sf "$DOTFILES_DIR/aliases" "$HOME/.bash_aliases" && success ".bash_aliases linked"
ln -sf "$DOTFILES_DIR/tmux.conf" "$HOME/.tmux.conf" && success ".tmux.conf linked"
ln -sf "$DOTFILES_DIR/functions/"*.sh "$HOME/.config/bash/functions/" && success "Functions linked"
ln -sf "$DOTFILES_DIR/gitconfig" "$HOME/.gitconfig" && success ".gitconfig linked"

# Logs
mkdir -p "$HOME/.logs/bash"

# SSH hardening check
if [[ $EUID -eq 0 ]] && [[ -f /etc/ssh/sshd_config ]]; then
    log "Checking SSH..."
    grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config && warn "Root login enabled - consider disabling"
    grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config && warn "Password auth enabled - consider key-only"
fi

echo ""
success "Done! Run: source ~/.bashrc"