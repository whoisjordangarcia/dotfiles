#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

NVIM_SOURCE="$SCRIPT_DIR/../../configs/nvim"
NVIM_TARGET="$HOME/.config/nvim"

mkdir -p "$HOME/.config.nvim"

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

link_file "$NVIM_SOURCE" "$NVIM_TARGET"

# if [ -f "~/.config/nvim" ]; then
# 	info "nvim exits skipping backup"
# else
# 	# info "Backing up nvim files"
# 	# mv ~/.config/nvim ~/.config/nvim_$DATE_SUFFIX.bak
# 	#
# 	# # optional but recommended
# 	# mv ~/.local/share/nvim ~/.local/share/nvim_$DATE_SUFFIX.bak
# 	# mv ~/.local/state/nvim ~/.local/state/nvim_$DATE_SUFFIX.bak
# 	# mv ~/.cache/nvim ~/.cache/nvim_$DATE_SUFFIX.bak
# fi
