#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

# ─────────────────────────────────────────────────────────────
# Install dolphin-plugins for Git integration and extras
# ─────────────────────────────────────────────────────────────
if command -v pacman &>/dev/null; then
    if ! pacman -Qi dolphin-plugins &>/dev/null; then
        info "Installing dolphin-plugins for Git integration..."
        sudo pacman -S --noconfirm dolphin-plugins
        success "dolphin-plugins installed"
    else
        info "dolphin-plugins already installed"
    fi
fi

# Ensure wl-copy is available for clipboard service menus (Wayland)
if command -v pacman &>/dev/null; then
    if ! command -v wl-copy &>/dev/null; then
        info "Installing wl-clipboard for copy-path service menu..."
        sudo pacman -S --noconfirm wl-clipboard
        success "wl-clipboard installed"
    fi
fi

# ─────────────────────────────────────────────────────────────
# Symlink dolphinrc configuration
# ─────────────────────────────────────────────────────────────
DOLPHIN_SOURCE="$SCRIPT_DIR/../../../configs/dolphin/dolphinrc"
DOLPHIN_TARGET="$HOME/.config/dolphinrc"

link_file "$DOLPHIN_SOURCE" "$DOLPHIN_TARGET"

# ─────────────────────────────────────────────────────────────
# Symlink service menus (right-click context actions)
# ─────────────────────────────────────────────────────────────
SERVICEMENUS_SOURCE="$SCRIPT_DIR/../../../configs/dolphin/servicemenus"
SERVICEMENUS_TARGET="$HOME/.local/share/kio/servicemenus"

# Create parent directory if needed
mkdir -p "$(dirname "$SERVICEMENUS_TARGET")"

# Symlink each service menu file individually (allows mixing with other service menus)
if [ -d "$SERVICEMENUS_SOURCE" ]; then
    mkdir -p "$SERVICEMENUS_TARGET"
    for menu_file in "$SERVICEMENUS_SOURCE"/*.desktop; do
        if [ -f "$menu_file" ]; then
            filename=$(basename "$menu_file")
            link_file "$menu_file" "$SERVICEMENUS_TARGET/$filename"
        fi
    done
    success "Service menus linked"
fi

# ─────────────────────────────────────────────────────────────
# Rebuild KDE service menu cache
# ─────────────────────────────────────────────────────────────
if command -v kbuildsycoca6 &>/dev/null; then
    info "Rebuilding KDE service cache..."
    kbuildsycoca6 --noincremental 2>/dev/null || true
    success "Service cache rebuilt"
elif command -v kbuildsycoca5 &>/dev/null; then
    info "Rebuilding KDE service cache..."
    kbuildsycoca5 --noincremental 2>/dev/null || true
    success "Service cache rebuilt"
fi

info "Dolphin setup complete! Restart Dolphin to apply changes."
