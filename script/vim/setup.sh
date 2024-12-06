#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
DATE_SUFFIX=$(date +%Y%m%d)

NVIM_PATH="$HOME/.config/nvim"

NVIM_SYMLINK_TARGET="$SCRIPT_DIR/../../configs/nvim"

mkdir -p "$HOME/.config.nvim"

source "$SCRIPT_DIR/../common/log.sh"

if [ -f "~/.config/nvim" ]; then
	info "nvim exits skipping backup"
else
	info "Backing up nvim files"
	mv ~/.config/nvim ~/.config/nvim_$DATE_SUFFIX.bak

	# optional but recommended
	mv ~/.local/share/nvim ~/.local/share/nvim_$DATE_SUFFIX.bak
	mv ~/.local/state/nvim ~/.local/state/nvim_$DATE_SUFFIX.bak
	mv ~/.cache/nvim ~/.cache/nvim_$DATE_SUFFIX.bak

	rm -rf ~/.config/nvim/.git

	# Create a symlink if config doesn't exist
	ln -s "$NVIM_SYMLINK_TARGET" "$NVIM_PATH"
	info "Symlink created for $NVIM_PATH"
fi
