#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"

FONT_DIR="~/.local/share/fonts"
FONT_FILE="JetBrainsMonoNerdFontMono-Regular.ttf"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/JetBrainsMono/Ligatures/Regular/$FONT_FILE"

info "Checking for $FONT_FILE in $FONT_DIR..."

mkdir -p "$FONT_DIR"

if [ -f "$FONT_DIR/$FONT_FILE" ]; then
	success "$FONT_FILE already exists. Skipping download."
else
	info "Downloading $FONT_FILE..."
	curl -fLo "$FONT_DIR/$FONT_FILE" "$FONT_URL"
	success "$FONT_FILE installed successfully."
fi

# Install Gohu font
info "Checking for Gohu fonts..."
if ls "$FONT_DIR"/Gohu* >/dev/null 2>&1; then
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
