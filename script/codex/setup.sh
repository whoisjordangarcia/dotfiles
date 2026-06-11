#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

# Make nvm-installed node available — this script runs as its own process,
# so it doesn't inherit nvm from the node component's shell.
# (nvm.sh is incompatible with `set -eu`, so relax around the source)
if ! command -v npm &>/dev/null && [ -s "$HOME/.nvm/nvm.sh" ]; then
    set +eu
    export NVM_DIR="$HOME/.nvm"
    \. "$NVM_DIR/nvm.sh"
    set -eu
fi

if ! command -v npm &>/dev/null; then
    fail "npm not found — skipping codex install. Run the node setup script first, then re-run this script."
fi

npm i -g @openai/codex -f

mkdir -p "$HOME/.codex"
link_file "$SCRIPT_DIR/../../configs/codex/config.toml" "$HOME/.codex/config.toml"

# Skills live in configs/skills and are projected into each agent CLI.
source "$SCRIPT_DIR/../skills/setup.sh"
