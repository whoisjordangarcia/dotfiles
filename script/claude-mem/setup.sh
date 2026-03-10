#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

debug "Ensuring $HOME/.claude-mem exists"
mkdir -p "$HOME/.claude-mem"

link_file "$SCRIPT_DIR/../../configs/claude-mem/settings.json" "$HOME/.claude-mem/settings.json"
