#!/bin/bash
# server-init.sh - One-line dotfiles installer
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/whoisjordangarcia/dotfiles/main/server-init.sh)

set -e
REPO="https://github.com/whoisjordangarcia/dotfiles.git"
DIR="$HOME/dotfiles"

RED='\033[0;31m' GREEN='\033[0;32m' BLUE='\033[0;34m' NC='\033[0m'
log() { echo -e "${BLUE}[DOTFILES]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }

echo ""
log "Installing Jordan's Dotfiles..."
echo ""

# Install deps (neovim is the preferred editor; bashrc falls back to vim/nano)
if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq git curl vim neovim tmux htop
fi

# Clone or update
if [[ -d "$DIR" ]]; then
    log "Updating existing dotfiles..."
    cd "$DIR" && git pull origin main
else
    log "Cloning dotfiles..."
    git clone "$REPO" "$DIR"
fi

# Run setup
cd "$DIR"
chmod +x server/setup.sh
bash server/setup.sh

echo ""
success "Installation complete!"