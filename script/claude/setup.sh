#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/../.." &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"
source "$SCRIPT_DIR/../common/dot_env.sh"
source "$SCRIPT_DIR/../common/bioprompt.sh"

# Resolve the environment ONCE for everything below: settings.json, the memory,
# and the sourced skills/setup.sh (which reads the exports this sets). See
# script/common/dot_env.sh for the precedence rules and why the .dotconfig
# fallback is load-bearing for standalone runs.
dot_export_env
debug "Claude environment: $DOT_ENV"

# Install Claude Code CLI if not present
if ! command -v claude &>/dev/null; then
	step "Installing Claude Code"
	curl -fsSL https://claude.ai/install.sh | bash
else
	debug "Claude Code already installed"
fi

debug "Ensuring $HOME/.claude exists"
mkdir -p "$HOME/.claude"

# Ensure source config directories exist before symlinking
mkdir -p "$SCRIPT_DIR/../../configs/claude/"{agents,commands,docs,prompts,themes}

link_file "$SCRIPT_DIR/../../configs/claude/agents/" "$HOME/.claude/agents" "directory"
link_file "$SCRIPT_DIR/../../configs/claude/commands/" "$HOME/.claude/commands" "directory"
# Work-machine reference docs, linked in on demand so the always-loaded memory stays
# short. The canonical memory points at the vault's notes for machine reference; these
# are the work-only ones.
link_file "$SCRIPT_DIR/../../configs/agents/docs/" "$HOME/.claude/docs" "directory"
link_file "$SCRIPT_DIR/../../configs/claude/prompts/" "$HOME/.claude/prompts" "directory"
# Custom themes: each themes/<slug>.json registers as `custom:<slug>` — the SLUG
# IS THE FILENAME, not the "name" field. Select via /theme or by setting
# "theme": "custom:<slug>" in settings.{work,personal}.json.
link_file "$SCRIPT_DIR/../../configs/claude/themes/" "$HOME/.claude/themes" "directory"
# NOTE: ~/.claude/skills is intentionally NOT a whole-dir symlink — skills are
# projected per-skill (work-only gating) by script/skills/setup.sh below.
# A whole-dir link here would make per-skill links resolve INTO the repo.
link_file "$SCRIPT_DIR/../../configs/claude/plugins/statusline-mod/cli/statusline.sh" "$HOME/.claude/statusline.sh"

# settings.json comes from a DEDICATED per-environment file (no base/overlay
# merge): configs/claude/settings.work.json or settings.personal.json, each a
# COMPLETE settings file. The active one is copied verbatim to ~/.claude (not
# symlinked, so the app can write runtime keys like model/effortLevel without
# touching the repo). That dedicated file is the single source of truth — run
# `claude-settings-sync` (script/claude/sync-settings.sh) to capture live edits
# back into it BEFORE re-running this script, or they'll be overwritten.
SETTINGS_SRC="$REPO_DIR/configs/claude/settings.${DOT_ENV}.json"
SETTINGS_TARGET="$HOME/.claude/settings.json"
[ -L "$SETTINGS_TARGET" ] && rm "$SETTINGS_TARGET"  # drop legacy symlink layout
cp "$SETTINGS_SRC" "$SETTINGS_TARGET"
success "Installed $SETTINGS_TARGET ($(basename "$SETTINGS_SRC"))"
# The copied settings.json names "./settings.schema.json" as its $schema.
link_file "$SCRIPT_DIR/../../configs/claude/settings.schema.json" "$HOME/.claude/settings.schema.json"

# User-scope MCP servers live in ~/.claude.json (app-owned, not tracked), so
# register them idempotently here. Cloudflare's MCP ships inside the
# cloudflare@cloudflare plugin (settings.personal.json) — don't add it here too
# or it shows up twice. Both authenticate via OAuth: run /mcp once per machine.
if [ "$DOT_ENV" = "personal" ]; then
	if ! claude mcp get vercel &>/dev/null; then
		claude mcp add --scope user --transport http vercel https://mcp.vercel.com
		success "Registered Vercel MCP (authenticate via /mcp)"
	else
		debug "Vercel MCP already registered"
	fi
	# Literal ${TAVILY_API_KEY}: Claude Code expands it at launch from the env .zshrc.sec exports,
	# so the key never lands in ~/.claude.json.
	if ! claude mcp get tavily &>/dev/null; then
		claude mcp add-json --scope user tavily \
			'{"command":"npx","args":["-y","tavily-mcp@latest"],"env":{"TAVILY_API_KEY":"${TAVILY_API_KEY}"}}'
		success "Registered Tavily MCP"
	else
		debug "Tavily MCP already registered"
	fi
fi

# The global memory is ONE file per machine (configs/agents/AGENTS.md, or AGENTS.work.md
# on work), symlinked into every place a harness reads it (~/.claude/CLAUDE.md for Claude
# Code's user scope, ~/.config/opencode/AGENTS.md for OpenCode). script/memory-sync.sh is
# the single generator; there is no dot-overlay marker and nothing to split back.
if bash "$SCRIPT_DIR/../memory-sync.sh"; then
	success "Linked the global memory from configs/agents/AGENTS.md"
else
	fail "memory-sync.sh failed — ~/.claude/CLAUDE.md may not point at the canonical memory"
fi

link_file "$SCRIPT_DIR/../../configs/claude/hooks/" "$HOME/.claude/hooks"

# Touch ID command gate (macOS): build BioPrompt.app — the SwiftUI approval
# dialog used by the touchid-gate.py PreToolUse hook to biometric-gate
# sensitive Bash commands. Shared with Codex (see script/common/bioprompt.sh);
# ~/.local/bin/bioprompt is a shim that execs the bundled binary (running it at
# its bundle path is what gives it app identity in the system auth UI).
build_bioprompt

# Skills live in configs/skills and are projected into each agent CLI.
source "$SCRIPT_DIR/../skills/setup.sh"

# Make nvm-installed node available — this script runs as its own process,
# so it doesn't inherit nvm from the node component's shell.
# (nvm.sh is incompatible with `set -eu`, so relax around the source)
if ! command -v npm &>/dev/null && [ -s "$HOME/.nvm/nvm.sh" ]; then
	set +eu
	export NVM_DIR="$HOME/.nvm"
	\. "$NVM_DIR/nvm.sh"
	set -eu
fi

# Install TypeScript language server for Claude Code's typescript-lsp plugin
if ! command -v typescript-language-server &>/dev/null; then
	if command -v npm &>/dev/null; then
		info "Installing typescript-language-server..."
		npm install -g typescript-language-server typescript
		success "typescript-language-server installed."
	else
		info "npm not found — skipping typescript-language-server install. Run 'npm install -g typescript-language-server typescript' manually after installing Node.js."
	fi
else
	debug "typescript-language-server already installed. Skipping."
fi
