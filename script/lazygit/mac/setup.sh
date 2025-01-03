#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

LAZYGIT_SOURCE="$HOME/~/Library/Application\ Support/lazygit/config.yml"
LAZYGIT_TARGET="$HOME/.config/lazygit/config.yml"

mkdir "$HOME/.config/lazygit"
link_file "$LAZYGIT_SOURCE" "$LAZYGIT_TARGET"
