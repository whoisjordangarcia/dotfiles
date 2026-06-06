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

# Codex owns ~/.codex/config.toml at runtime (it rewrites trust paths, marketplace
# state, desktop SHA256s, etc.), so we SEED it from a sanitized template instead of
# symlinking — symlinking would push that machine/work-specific state back into this
# public repo. Only seed when the file is absent so we never clobber a live config.
CODEX_TEMPLATE="$SCRIPT_DIR/../../configs/codex/config.toml.template"
CODEX_CONFIG="$HOME/.codex/config.toml"
if [ ! -e "$CODEX_CONFIG" ]; then
    step "Seeding $CODEX_CONFIG from template"
    cp "$CODEX_TEMPLATE" "$CODEX_CONFIG"
else
    info "$CODEX_CONFIG already exists — leaving it untouched"
fi

# Skills live in configs/skills and are projected into each agent CLI.
source "$SCRIPT_DIR/../skills/setup.sh"
