#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

mkdir -p "$HOME/.codex"
link_file "$SCRIPT_DIR/../../configs/codex/config.toml" "$HOME/.codex/config.toml"
