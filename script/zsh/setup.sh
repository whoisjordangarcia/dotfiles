#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"

ZSHRC_PATH="$HOME/.zshrc"

# Get current date in YYYYMMDD format
DATE_SUFFIX=$(date +%Y%m%d)

ZSHRC_BACKUP_PATH="$HOME/.zshrc_backup_$DATE_SUFFIX"

ZSHRC_SYMLINK_TARGET="$SCRIPT_DIR/../../configs/zshrc/.zshrc"

# Install oh-my-zsh
info "installing oh-my-zsh..."
info "make sure to add correct credentials"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install powerlevel 10k
info "installing powerlevel10k..."
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

if [ -f "$ZSHRC_PATH" ]; then
	info "Identified .zshrc exists creating backup"
	# Backup the file
	cp "$ZSHRC_PATH" "$ZSHRC_BACKUP_PATH"
	echo "Backup created at $ZSHRC_BACKUP_PATH"

	info "Deleting file $ZSHRC_PATH"
	rm "$ZSHRC_PATH"
fi

# Create a symlink if .zshrc doesn't exist
ln -s "$ZSHRC_SYMLINK_TARGET" "$ZSHRC_PATH"
info "Symlink created for $ZSHRC_PATH"

# Default zsh
info "Defaulting zsh..."
chsh -s $(which zsh)

# Install zsh plugins
"$SCRIPT_DIR/plugins/zsh_plugins.sh"
