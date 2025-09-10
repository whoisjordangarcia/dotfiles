#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/symlink.sh"

link_file "$SCRIPT_DIR/../../../configs/claude/agents" "$HOME/.claude/agents"
link_file "$SCRIPT_DIR/../../../configs/claude/commands" "$HOME/.claude/commands"
link_file "$SCRIPT_DIR/../../../configs/claude/prompts" "$HOME/.claude/prompts"
link_file "$SCRIPT_DIR/../../../configs/claude/settings.json" "$HOME/.claude/settings.json"
