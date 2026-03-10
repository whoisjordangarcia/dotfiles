#!/bin/bash
#===============================================================================
# server-init.sh - One-line dotfiles installer for any server
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/whoisjordangarcia/dotfiles/main/server-init.sh)
#===============================================================================

set -e

# Configuration
DOTFILES_REPO="https://github.com/whoisjordangarcia/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[DOTFILES]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "$ID"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/redhat-release ]]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

# Install dependencies
install_deps() {
    local os="$1"
    log "Installing dependencies for $os..."
    
    case "$os" in
        ubuntu|debian)
            sudo apt-get update -qq
            sudo apt-get install -y -qq git curl vim tmux htop wget curl
            ;;
        fedora|rhel|centos)
            sudo dnf install -y git curl vim tmux htop wget
            ;;
        arch)
            sudo pacman -Sy --noconfirm git curl vim tmux htop wget
            ;;
        *)
            warn "Unknown OS - skipping dependency installation"
            ;;
    esac
    success "Dependencies installed"
}

# Main installation
main() {
    echo ""
    log "Jordan's Dotfiles Installer"
    log "============================"
    echo ""
    
    local os
    os=$(detect_os)
    log "Detected OS: $os"
    
    # Create backup directory
    if [[ -d "$HOME/.bashrc" ]] || [[ -d "$HOME/.bash_aliases" ]]; then
        log "Creating backup at $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
        [[ -f "$HOME/.bashrc" ]] && cp "$HOME/.bashrc" "$BACKUP_DIR/"
        [[ -f "$HOME/.bash_aliases" ]] && cp "$HOME/.bash_aliases" "$BACKUP_DIR/"
        [[ -f "$HOME/.bash_profile" ]] && cp "$HOME/.bash_profile" "$BACKUP_DIR/"
        [[ -f "$HOME/.tmux.conf" ]] && cp "$HOME/.tmux.conf" "$BACKUP_DIR/"
        [[ -f "$HOME/.gitconfig" ]] && cp "$HOME/.gitconfig" "$BACKUP_DIR/"
    fi
    
    # Install deps
    install_deps "$os"
    
    # Clone repo
    if [[ -d "$DOTFILES_DIR" ]]; then
        log "Updating existing dotfiles..."
        cd "$DOTFILES_DIR" && git pull origin main
    else
        log "Cloning dotfiles..."
        git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    fi
    
    # Link files
    log "Linking configuration files..."
    
    # Bash
    ln -sf "$DOTFILES_DIR/configs/bashrc/.bashrc" "$HOME/.bashrc" 2>/dev/null || true
    ln -sf "$DOTFILES_DIR/aliases" "$HOME/.bash_aliases" 2>/dev/null || true
    ln -sf "$DOTFILES_DIR/bash_profile" "$HOME/.bash_profile" 2>/dev/null || true
    
    # Tmux
    ln -sf "$DOTFILES_DIR/tmux.conf" "$HOME/.tmux.conf" 2>/dev/null || true
    
    # Git
    ln -sf "$DOTFILES_DIR/gitconfig" "$HOME/.gitconfig" 2>/dev/null || true
    
    # Functions
    mkdir -p "$HOME/.config/bash/functions"
    for f in "$DOTFILES_DIR/functions"/*.sh; do
        [[ -f "$f" ]] && ln -sf "$f" "$HOME/.config/bash/functions/" 2>/dev/null || true
    done
    
    # Create logs directory
    mkdir -p "$HOME/.logs/bash"
    
    success "Installation complete!"
    echo ""
    log "Next steps:"
    echo "  1. source ~/.bashrc"
    echo "  2. Edit ~/.gitconfig with your info"
    echo ""
    
    # Check if Proxmox
    if [[ -f /etc/pve/proxmox-release ]]; then
        log "Proxmox VE detected - Proxmox aliases available!"
    fi
    
    # Check if Docker
    if command -v docker &>/dev/null; then
        log "Docker detected - Docker aliases available!"
    fi
}

main "$@"