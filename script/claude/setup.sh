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
link_file "$SCRIPT_DIR/../../configs/claude/statusline.sh" "$HOME/.claude/statusline.sh"
link_file "$SCRIPT_DIR/../../configs/claude/settings.json" "$HOME/.claude/settings.json"
link_file "$SCRIPT_DIR/../../configs/claude/hooks/" "$HOME/.claude/hooks"

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
