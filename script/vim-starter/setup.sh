#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
DOTFILES_ROOT=$(cd -- "$SCRIPT_DIR/../.." &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

NVIM_SOURCE="$DOTFILES_ROOT/configs/nvim-starter"
NVIM_TARGET="$HOME/.config/nvim"

mkdir -p "$HOME/.config"

link_file "$NVIM_SOURCE" "$NVIM_TARGET"
