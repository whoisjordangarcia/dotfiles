#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

# ~/.agents must be a real directory. It used to be a symlink to configs/agents, which put ~/.agents/skills —
# the skills CLI's install root and the target script/skills/setup.sh copies into — inside this repo: every
# sync showed up as untracked files and third-party installs got committed. Convert it once, keeping the skills.
AGENTS_HOME="$HOME/.agents"
REPO_AGENTS=$(cd -- "$SCRIPT_DIR/../../configs/agents" &>/dev/null && pwd -P)
if [ -L "$AGENTS_HOME" ] && [ "$(cd -- "$AGENTS_HOME" 2>/dev/null && pwd -P)" = "$REPO_AGENTS" ]; then
    rm "$AGENTS_HOME"
    mkdir -p "$AGENTS_HOME"
    if [ -d "$REPO_AGENTS/skills" ]; then
        mv "$REPO_AGENTS/skills" "$AGENTS_HOME/skills"
    fi
    info "~/.agents was a symlink into the dotfiles; it is now a real directory (skills moved with it)"
fi

mkdir -p "$AGENTS_HOME"
link_file "$SCRIPT_DIR/../../configs/agents/.skill-lock.json" "$HOME/.agents/.skill-lock.json"

# Skills are shared across Claude, Cursor, Codex, and ~/.agents.
source "$SCRIPT_DIR/../skills/setup.sh"
