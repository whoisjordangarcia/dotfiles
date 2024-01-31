#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
DATE_SUFFIX=$(date +%Y%m%d)
source "$SCRIPT_DIR/../common/log.sh"

info "Backing up nvim files"

# required
mv ~/.config/nvim ~/.config/nvim_$DATE_SUFFIX.bak

# optional but recommended
mv ~/.local/share/nvim ~/.local/share/nvim_$DATE_SUFFIX.bak
mv ~/.local/state/nvim  ~/.local/state/nvim_$DATE_SUFFIX.bak
mv ~/.cache/nvim ~/.cache/nvim_$DATE_SUFFIX.bak

git clone https://github.com/LazyVim/starter ~/.config/nvim

rm -rf ~/.config/nvim/.git
