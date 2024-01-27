#!/bin/bash
source ../common/log.sh

ZSHRC_PATH="$HOME/.zshrc"

# Get current date in YYYYMMDD format
DATE_SUFFIX=$(date +%Y%m%d)

ZAHRC_BACKUP_PATH="$HOME/.zshrc_backup_$DATE_SUFFIX"

CURRENT_DIR=$(pwd)

ZSHRC_SYMLINK_TARGET="$CURRENT_DIR/../../configs/.zshrc"

if [ -f "$ZSHRC_PATH" ]; then
    info "Identified .zshrc exists creating backup"
    # Backup the file
    cp "$ZSHRC_PATH" "$ZAHRC_BACKUP_PATH"
    echo "Backup created at $BACKUP_PATH"
fi    

# Create a symlink if .zshrc doesn't exist
ln -s "$ZSHRC_SYMLINK_TARGET" "$ZSHRC_PATH"
info "Symlink created for $ZSHRC_PATH"


# Install zsh plugins
./script/zsh/plugins/zsh_plugin.sh