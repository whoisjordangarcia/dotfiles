#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"

FONT_DIR="$HOME/.local/share/fonts"
FONT_FILE="JetBrainsMonoNerdFontMono-Regular.ttf"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/JetBrainsMono/Ligatures/Regular/$FONT_FILE"

# Gohu font variables
GOHU_ZIP_URL="https://github.com/koemaeda/gohufont-ttf/archive/refs/heads/master.zip"
GOHU_ZIP_FILE="/tmp/gohufont.zip"
TEMP_DIR="/tmp/gohufont-extract"

debug "Checking for $FONT_FILE in $FONT_DIR..."

mkdir -p "$FONT_DIR"

if [ -f "$FONT_DIR/$FONT_FILE" ]; then
	debug "$FONT_FILE already exists. Skipping download."
else
	info "Downloading $FONT_FILE..."
	curl -fLo "$FONT_DIR/$FONT_FILE" "$FONT_URL"
	success "$FONT_FILE installed successfully."
fi

# Install Gohu font
debug "Checking for Gohu fonts..."
if ls "$FONT_DIR"/gohufont*.ttf >/dev/null 2>&1; then
	debug "Gohu fonts already exist. Skipping download."
else
	info "Downloading Gohu font zip..."
	curl -fLo "$GOHU_ZIP_FILE" "$GOHU_ZIP_URL"

	info "Extracting Gohu fonts..."
	mkdir -p "$TEMP_DIR"
	unzip -q "$GOHU_ZIP_FILE" -d "$TEMP_DIR"

	info "Installing Gohu fonts..."
	find "$TEMP_DIR" -name "*.ttf" -o -name "*.otf" | while read -r font_file; do
		cp "$font_file" "$FONT_DIR/"
		info "Installed $(basename "$font_file")"
	done

	# Cleanup
	rm -rf "$GOHU_ZIP_FILE" "$TEMP_DIR"

	success "Gohu fonts installed successfully."
fi
