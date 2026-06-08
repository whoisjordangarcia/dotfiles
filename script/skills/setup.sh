#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

SKILLS_SOURCE="$REPO_ROOT/configs/skills"

ensure_skill_dir() {
	local target_dir="$1"

	mkdir -p "$target_dir"
}

link_shared_skills() {
	local target_dir="$1"

	ensure_skill_dir "$target_dir"

	local skill_dir skill_name
	for skill_dir in "$SKILLS_SOURCE"/*; do
		[ -d "$skill_dir" ] || continue
		[ -f "$skill_dir/SKILL.md" ] || continue

		skill_name=$(basename "$skill_dir")
		link_file "$skill_dir" "$target_dir/$skill_name"
	done
}

if [ ! -d "$SKILLS_SOURCE" ]; then
	fail "Shared skills source not found: $SKILLS_SOURCE"
fi

step "Linking shared agent skills"
link_shared_skills "$HOME/.claude/skills"
link_shared_skills "$HOME/.cursor/skills"
link_shared_skills "$HOME/.codex/skills"
link_shared_skills "$HOME/.agents/skills"
