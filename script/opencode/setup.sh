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

# `browse` MCP CLI, referenced by mcp.servers.browse in opencode.json. Only the CLI is installed here;
# the browser extension is added by hand from the Chrome Web Store, then paired with `browse install`.
if ! command -v browse &>/dev/null; then
	npm install -g @opencode/browse
	success "Installed browse CLI (add the extension from the Chrome Web Store, then run: browse install)"
else
	debug "browse CLI already installed"
fi

mkdir -p "$HOME/.config/opencode"
link_file "$SCRIPT_DIR/../../configs/opencode/opencode.json" "$HOME/.config/opencode/opencode.json"
mkdir -p "$HOME/.config/opencode/plugins"
link_file "$SCRIPT_DIR/../../configs/opencode/plugins/statusline-mod" "$HOME/.config/opencode/plugins/statusline-mod"

# The background service doesn't inherit the shell's env, so .zshrc's export never reaches it: hide the
# free opencode/opencode-go models on the service itself.
opencode service set env OPENCODE_DISABLE_FREE_MODELS 1 || warn "couldn't set OPENCODE_DISABLE_FREE_MODELS on the opencode service"

if [ -d "/Applications/Rex Beta.app" ]; then
	python3 "$SCRIPT_DIR/../../configs/opencode/rex-themes.py"
fi
