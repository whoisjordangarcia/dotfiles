#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

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
mkdir -p "$SCRIPT_DIR/../../configs/claude/"{agents,commands,prompts}

link_file "$SCRIPT_DIR/../../configs/claude/agents/" "$HOME/.claude/agents" "directory"
link_file "$SCRIPT_DIR/../../configs/claude/commands/" "$HOME/.claude/commands" "directory"
link_file "$SCRIPT_DIR/../../configs/claude/prompts/" "$HOME/.claude/prompts" "directory"
# NOTE: ~/.claude/skills is intentionally NOT a whole-dir symlink — skills are
# projected per-skill (work-only gating) by script/skills/setup.sh below.
# A whole-dir link here would make per-skill links resolve INTO the repo.
link_file "$SCRIPT_DIR/../../configs/claude/statusline.sh" "$HOME/.claude/statusline.sh"

# settings.json is GENERATED (base + work/personal overlay), not symlinked, so
# work-only plugins/marketplaces never follow personal machines around. The
# repo is authoritative for the structured blocks (enabledPlugins, hooks,
# permissions, marketplaces); machine-local drift the app writes at runtime
# (model, effortLevel, ...) survives regeneration via the existing-file merge.
SETTINGS_BASE="$SCRIPT_DIR/../../configs/claude/settings.base.json"
if [[ "${WORK_ENV:-}" == "1" || "${DOT_ENVIRONMENT:-}" == "work" ]]; then
	SETTINGS_OVERLAY="$SCRIPT_DIR/../../configs/claude/settings.work.json"
else
	SETTINGS_OVERLAY="$SCRIPT_DIR/../../configs/claude/settings.personal.json"
fi
SETTINGS_TARGET="$HOME/.claude/settings.json"
if ! command -v jq &>/dev/null; then
	fail "jq is required to generate Claude settings (brew/apt install jq)"
fi
# Capture current settings (drift source) BEFORE touching the target — the
# legacy layout was a symlink to the repo file, which we then replace.
SETTINGS_EXISTING="{}"
[ -f "$SETTINGS_TARGET" ] && SETTINGS_EXISTING=$(cat "$SETTINGS_TARGET")
[ -L "$SETTINGS_TARGET" ] && rm "$SETTINGS_TARGET"
printf '%s' "$SETTINGS_EXISTING" | jq -s \
	'(.[0] // {}) as $cur | (.[1] * .[2]) as $repo |
	 ($cur * $repo)
	 + {enabledPlugins: $repo.enabledPlugins, hooks: $repo.hooks, permissions: $repo.permissions}
	 + (if $repo.extraKnownMarketplaces then {extraKnownMarketplaces: $repo.extraKnownMarketplaces} else {} end)' \
	- "$SETTINGS_BASE" "$SETTINGS_OVERLAY" >"${SETTINGS_TARGET}.tmp" \
	&& mv "${SETTINGS_TARGET}.tmp" "$SETTINGS_TARGET"
success "Generated $SETTINGS_TARGET ($(basename "$SETTINGS_OVERLAY"))"

link_file "$SCRIPT_DIR/../../configs/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
link_file "$SCRIPT_DIR/../../configs/claude/hooks/" "$HOME/.claude/hooks"
# cmux sidebar hook scripts (workspace title, PR-approval pill, task progress bar)
link_file "$SCRIPT_DIR/../../configs/claude/scripts/" "$HOME/.claude/scripts" "directory"

# Touch ID command gate (macOS): compile the bioprompt helper used by the
# touchid-gate.py PreToolUse hook to biometric-gate sensitive Bash commands.
if [[ "$OSTYPE" == darwin* ]] && command -v swiftc &>/dev/null; then
	BIOPROMPT_SRC="$SCRIPT_DIR/../../configs/claude/hooks/bioprompt.swift"
	BIOPROMPT_BIN="$HOME/.local/bin/bioprompt"
	if [[ ! -x "$BIOPROMPT_BIN" || "$BIOPROMPT_SRC" -nt "$BIOPROMPT_BIN" ]]; then
		step "Compiling bioprompt (Touch ID helper)..."
		mkdir -p "$(dirname "$BIOPROMPT_BIN")"
		swiftc -O "$BIOPROMPT_SRC" -o "$BIOPROMPT_BIN"
		success "bioprompt compiled to $BIOPROMPT_BIN"
	else
		debug "bioprompt already compiled and up to date. Skipping."
	fi
fi

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
