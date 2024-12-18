#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"

TMUX_PATH="$HOME/.tmux.conf"

# Get current date in YYYYMMDD format
DATE_SUFFIX=$(date +%Y%m%d)

TMUX_BACKUP_PATH="$HOME/.tmux.conf_backup_$DATE_SUFFIX"

TMUX_SYMLINK_TARGET="$SCRIPT_DIR/../../configs/tmux/.tmux.conf"

git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

if [ -f "$TMUX_PATH" ]; then
	error "Identified .tmux.conf exists. Please delete $TMUX_PATH"

	# Backup the file
	#cp "$TMUX_PATH" "$TMUX_BACKUP_PATH"
	#echo "Backup created at $TMUX_BACKUP_PATH"

	#info "Deleting file $TMUX_PATH"
	#rm "$TMUX_PATH"
fi

# Create a symlink if .zshrc doesn't exist
ln -s "$TMUX_SYMLINK_TARGET" "$TMUX_PATH"
info "Symlink created for $TMUX_PATH"
