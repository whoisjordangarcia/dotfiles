#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_DIR/../../common/log.sh"

info "Setting up Neovim nightly..."

# Create local neovim directory
NEOVIM_DIR="$HOME/.local/neovim"
mkdir -p "$NEOVIM_DIR"

# Detect architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    DOWNLOAD_URL="https://github.com/neovim/neovim/releases/download/nightly/nvim-macos-arm64.tar.gz"
    info "Detected ARM64 architecture"
elif [[ "$ARCH" == "x86_64" ]]; then
    DOWNLOAD_URL="https://github.com/neovim/neovim/releases/download/nightly/nvim-macos-x86_64.tar.gz"
    info "Detected x86_64 architecture"
else
    error "Unsupported architecture: $ARCH"
    exit 1
fi

# Download and extract Neovim nightly
info "Downloading Neovim nightly from $DOWNLOAD_URL"
TEMP_FILE=$(mktemp)
if curl -L "$DOWNLOAD_URL" -o "$TEMP_FILE"; then
    success "Downloaded Neovim nightly"
else
    error "Failed to download Neovim nightly"
    exit 1
fi

# Remove existing installation if present
if [[ -d "$NEOVIM_DIR/nvim-macos-arm64" ]] || [[ -d "$NEOVIM_DIR/nvim-macos-x86_64" ]]; then
    info "Removing existing Neovim installation"
    rm -rf "$NEOVIM_DIR"/nvim-macos-*
fi

# Extract to neovim directory
info "Extracting Neovim to $NEOVIM_DIR"
if tar -xzf "$TEMP_FILE" -C "$NEOVIM_DIR"; then
    success "Extracted Neovim nightly"
else
    error "Failed to extract Neovim nightly"
    exit 1
fi

# Clean up temp file
rm "$TEMP_FILE"

# Create symlink for easier access
EXTRACTED_DIR=""
if [[ "$ARCH" == "arm64" ]]; then
    EXTRACTED_DIR="$NEOVIM_DIR/nvim-macos-arm64"
elif [[ "$ARCH" == "x86_64" ]]; then
    EXTRACTED_DIR="$NEOVIM_DIR/nvim-macos-x86_64"
fi

if [[ -d "$EXTRACTED_DIR" ]]; then
    # Remove existing symlink if present
    [[ -L "$NEOVIM_DIR/current" ]] && rm "$NEOVIM_DIR/current"

    # Create new symlink
    ln -sf "$EXTRACTED_DIR" "$NEOVIM_DIR/current"
    success "Created symlink at $NEOVIM_DIR/current"
else
    error "Extraction directory not found: $EXTRACTED_DIR"
    exit 1
fi

# Verify installation
if [[ -x "$NEOVIM_DIR/current/bin/nvim" ]]; then
    NVIM_VERSION=$("$NEOVIM_DIR/current/bin/nvim" --version | head -n1)
    success "Neovim nightly installed successfully: $NVIM_VERSION"
    info "Neovim binary location: $NEOVIM_DIR/current/bin/nvim"
    info "Add $NEOVIM_DIR/current/bin to your PATH to use this version"
else
    error "Neovim binary not found or not executable"
    exit 1
fi