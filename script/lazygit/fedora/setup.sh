#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

LAZYGIT_SOURCE="$SCRIPT_DIR/../../configs/lazygit/config.yml"
LAZYGIT_TARGET="$HOME/.config/lazygit/config.yml"

sudo dnf copr enable atim/lazygit -y
sudo dnf install lazygit

link_file "$LAZYGIT_SOURCE" "$LAZYGIT_TARGET"