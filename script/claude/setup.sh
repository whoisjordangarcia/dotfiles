#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

debug "Ensuring $HOME/.claude exists"
mkdir -p "$HOME/.claude"

link_file "$SCRIPT_DIR/../../configs/claude/agents/" "$HOME/.claude/agents" "directory"
link_file "$SCRIPT_DIR/../../configs/claude/commands/" "$HOME/.claude/commands" "directory"
link_file "$SCRIPT_DIR/../../configs/claude/prompts/" "$HOME/.claude/prompts" "directory"
link_file "$SCRIPT_DIR/../../configs/claude/statusline.sh" "$HOME/.claude/statusline.sh"
link_file "$SCRIPT_DIR/../../configs/claude/settings.json" "$HOME/.claude/settings.json"

# /plugin marketplace add obra/superpowers-marketplace
# /plugin install superpowers-developing-for-claude-code@superpowers-marketplace
#
# /plugin marketplace add sawyerhood/dev-browser
# /plugin install dev-browser@sawyerhood/dev-browser
#
# /plugin marketplace add thedotmack/claude-mem
# /plugin install claude-mem
