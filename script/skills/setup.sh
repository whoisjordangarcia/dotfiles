#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

SKILLS_SOURCE="$REPO_ROOT/configs/skills"

# nest-* skills are work-only — install them in work mode, prune them elsewhere
IS_WORK_ENV=0
if [[ "${WORK_ENV:-}" == "1" || "${DOT_ENVIRONMENT:-}" == "work" ]]; then
	IS_WORK_ENV=1
fi

ensure_skill_dir() {
	local target_dir="$1"

	# Legacy layout: the target itself was a symlink to the repo skills dir.
	# Per-skill links through such a parent resolve INTO the repo and can
	# replace real skill dirs with self-referential symlinks — dissolve it.
	if [ -L "$target_dir" ]; then
		rm "$target_dir"
		info "Replaced legacy whole-dir symlink with real dir: $target_dir"
	fi

	mkdir -p "$target_dir"

	# Belt-and-braces: never operate on a target that resolves into the repo.
	local resolved
	resolved=$(realpath "$target_dir" 2>/dev/null || echo "$target_dir")
	if [[ "$resolved" == "$SKILLS_SOURCE" || "$resolved" == "$SKILLS_SOURCE"/* ]]; then
		fail "Refusing to link skills: $target_dir resolves into $SKILLS_SOURCE"
	fi
}

link_shared_skills() {
	local target_dir="$1"

	ensure_skill_dir "$target_dir"

	local skill_dir skill_name
	for skill_dir in "$SKILLS_SOURCE"/*; do
		[ -d "$skill_dir" ] || continue
		[ -f "$skill_dir/SKILL.md" ] || continue

		skill_name=$(basename "$skill_dir")

		# Work-only skills: skip outside work mode, and remove any link a
		# previous (pre-gating or work-mode) run left behind.
		if [[ "$skill_name" == nest-* && "$IS_WORK_ENV" != 1 ]]; then
			if [ -L "$target_dir/$skill_name" ]; then
				rm "$target_dir/$skill_name"
				info "Pruned work-only skill: $target_dir/$skill_name"
			fi
			continue
		fi

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
