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
# Env is read from .dotconfig (DOT_ENVIRONMENT), overridable with WORK_ENV=1.
# 1:1 copy: no merge, no routing.
#===============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_DIR/../common/log.sh"
REPO_DIR=$(cd -- "$SCRIPT_DIR/../.." &>/dev/null && pwd)

LIVE="${1:-$HOME/.claude/settings.json}"
[ -f "$LIVE" ] || fail "No live settings at $LIVE"
if [ -L "$LIVE" ]; then
	fail "$LIVE is a symlink (legacy layout). Run script/claude/setup.sh first."
fi

# Resolve environment: explicit WORK_ENV wins, else .dotconfig's DOT_ENVIRONMENT.
env_name="personal"
if [[ "${WORK_ENV:-}" == "1" ]]; then
	env_name="work"
elif [ -f "$REPO_DIR/.dotconfig" ]; then
	# shellcheck disable=SC1091
	dotenv=$(grep -E '^DOT_ENVIRONMENT=' "$REPO_DIR/.dotconfig" | head -1 | cut -d'"' -f2)
	[ "$dotenv" = "work" ] && env_name="work"
fi
DEST="$REPO_DIR/configs/claude/settings.${env_name}.json"

step "Syncing $LIVE → settings.${env_name}.json"
cp "$LIVE" "$DEST"
success "Wrote $(basename "$DEST")"
info "Review with: git -C \"$REPO_DIR\" diff configs/claude/settings.${env_name}.json"
