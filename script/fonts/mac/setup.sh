#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"

FONT_DIR=~/Library/Fonts
TEMP_DIR=$(mktemp -d)

# JetBrains Mono font
JETBRAINS_FONT_FILE="JetBrainsMonoNerdFontMono-Regular.ttf"
JETBRAINS_FONT_URL="https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/JetBrainsMono/Ligatures/Regular/$JETBRAINS_FONT_FILE"

# Gohu font
GOHU_ZIP_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Gohu.zip"
GOHU_ZIP_FILE="$TEMP_DIR/Gohu.zip"

mkdir -p "$FONT_DIR"

# Install JetBrains Mono
info "Checking for $JETBRAINS_FONT_FILE in $FONT_DIR..."
if [ -f "$FONT_DIR/$JETBRAINS_FONT_FILE" ]; then
	success "$JETBRAINS_FONT_FILE already exists. Skipping download."
else
	info "Downloading $JETBRAINS_FONT_FILE..."
	curl -fLo "$FONT_DIR/$JETBRAINS_FONT_FILE" "$JETBRAINS_FONT_URL"
	success "$JETBRAINS_FONT_FILE installed successfully."
fi

# Install Gohu font
info "Checking for Gohu fonts..."
if ls "$FONT_DIR"/gohu* >/dev/null 2>&1; then
	success "Gohu fonts already exist. Skipping download."
else
	info "Downloading Gohu font zip..."
	curl -fLo "$GOHU_ZIP_FILE" "$GOHU_ZIP_URL"
	
	info "Extracting Gohu fonts..."
	unzip -q "$GOHU_ZIP_FILE" -d "$TEMP_DIR"
	
	info "Installing Gohu fonts to Font Book..."
	find "$TEMP_DIR" -name "*.ttf" -o -name "*.otf" | while read -r font_file; do
		cp "$font_file" "$FONT_DIR/"
		info "Installed $(basename "$font_file")"
	done
	
	success "Gohu fonts installed successfully."
fi

# Clean up temporary directory
rm -rf "$TEMP_DIR"
