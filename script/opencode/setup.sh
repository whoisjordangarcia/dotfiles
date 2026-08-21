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
	fail "npm not found — skipping opencode install. Run the node setup script first, then re-run this script."
fi

# OpenCode 2 (bin: `opencode2`) is the default install. It is a different
# distribution channel from v1 — NOT a flag on the old curl installer, which
# only ever ships v1 (bin: `opencode`) into ~/.opencode/bin.
#
# The `@next` tag is load-bearing, never drop it: `@opencode-ai/cli@latest`
# resolves to 1.18.15 whose only bin is `lildax`, an unrelated program. A bare
# `npm i -g @opencode-ai/cli` therefore installs the wrong thing and still exits
# 0, leaving no `opencode2` on PATH and no error to explain why.
#
# Unconditional, like the codex component: `next` is a moving prerelease, and a
# `command -v opencode2` guard would freeze each machine on whatever build it
# first saw — the opposite of tracking the channel.
info "Installing OpenCode 2 (@opencode-ai/cli@next)..."
npm i -g @opencode-ai/cli@next -f
success "OpenCode 2 installed: $(opencode2 --version 2>/dev/null || echo unknown)"

mkdir -p "$HOME/.config/opencode"
link_file "$SCRIPT_DIR/../../configs/opencode/opencode.json" "$HOME/.config/opencode/opencode.json"
