#!/bin/bash
#===============================================================================
# sync-settings.sh — capture live ~/.claude/settings.json back into the repo.
#
# settings.json uses DEDICATED per-environment files (no base/overlay merge):
# configs/claude/settings.work.json and settings.personal.json are each complete.
# setup.sh copies the active one to ~/.claude/settings.json; this script does the
# reverse — copies the live file back into the active env's dedicated file — so
# edits/app drift you want to keep get version-controlled.
#
# Env resolution is shared with setup.sh via script/common/dot_env.sh, so the
# forward (setup) and reverse (sync) directions can never disagree about which
# machine this is. 1:1 copy: no merge, no routing.
#===============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/dot_env.sh"
REPO_DIR=$(cd -- "$SCRIPT_DIR/../.." &>/dev/null && pwd)

LIVE="${1:-$HOME/.claude/settings.json}"
[ -f "$LIVE" ] || fail "No live settings at $LIVE"
if [ -L "$LIVE" ]; then
	fail "$LIVE is a symlink (legacy layout). Run script/claude/setup.sh first."
fi

# Resolve environment (shared with setup.sh — see script/common/dot_env.sh).
dot_export_env
env_name="$DOT_ENV"
DEST="$REPO_DIR/configs/claude/settings.${env_name}.json"

step "Syncing $LIVE → settings.${env_name}.json"
cp "$LIVE" "$DEST"
success "Wrote $(basename "$DEST")"
info "Review with: git -C \"$REPO_DIR\" diff configs/claude/settings.${env_name}.json"
