#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

mkdir -p "$HOME/.config/gh/"

link_file "$SCRIPT_DIR/../../configs/gh/config.yml" "$HOME/.config/gh/config.yml"
