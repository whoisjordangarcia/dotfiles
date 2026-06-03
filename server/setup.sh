#!/bin/bash
# Dotfiles Setup Script

set -euo pipefail
# This script lives in server/; DOTFILES_DIR is that folder, REPO_ROOT its parent.
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$DOTFILES_DIR/.." && pwd)"
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
# functions/ and gitconfig live at the repo root, shared with the rest of the dotfiles
ln -sf "$REPO_ROOT/functions/"*.sh "$HOME/.config/bash/functions/" && success "Functions linked"
ln -sf "$REPO_ROOT/gitconfig" "$HOME/.gitconfig" && success ".gitconfig linked"

# Logs
mkdir -p "$HOME/.logs/bash"

# Claude Code — primary tool on these servers. Native installer drops the binary
# in ~/.local/bin (already first on PATH via bashrc), so no node/npm/pnpm needed.
# Skip with SKIP_CLAUDE=1; already-installed installs are left untouched.
if [[ "${SKIP_CLAUDE:-0}" != "1" ]]; then
    if command -v claude &>/dev/null; then
        success "Claude Code already installed ($(claude --version 2>/dev/null || echo present))"
    else
        log "Installing Claude Code..."
        if curl -fsSL https://claude.ai/install.sh | bash; then
            success "Claude Code installed to ~/.local/bin"
        else
            warn "Claude Code install failed — run later: curl -fsSL https://claude.ai/install.sh | bash"
        fi
    fi
fi

# SSH hardening check
if [[ $EUID -eq 0 ]] && [[ -f /etc/ssh/sshd_config ]]; then
    log "Checking SSH..."
    grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config && warn "Root login enabled - consider disabling"
    grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config && warn "Password auth enabled - consider key-only"
fi

echo ""
success "Done! Run: source ~/.bashrc"