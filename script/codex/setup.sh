#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

if ! command -v npm &>/dev/null; then
    fail "npm not found — skipping codex install. Run the node setup script first, then re-run this script."
fi

npm i -g @openai/codex -f

mkdir -p "$HOME/.codex"
link_file "$SCRIPT_DIR/../../configs/codex/config.toml" "$HOME/.codex/config.toml"
