#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

mkdir -p "$HOME/.agents"
link_file "$SCRIPT_DIR/../../configs/agents/.skill-lock.json" "$HOME/.agents/.skill-lock.json"

# Skills are shared across Claude, Cursor, Codex, and ~/.agents.
source "$SCRIPT_DIR/../skills/setup.sh"
