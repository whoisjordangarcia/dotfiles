#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"
source "$SCRIPT_DIR/../common/dot_env.sh"

SKILLS_SOURCE="$REPO_ROOT/configs/skills"

# nest-* skills are work-only — install them in work mode, prune them elsewhere.
# Resolution is shared (script/common/dot_env.sh) so a STANDALONE run here agrees
# with claude/setup.sh; previously this read the env only, so running it directly
# on a work machine pruned every nest-* skill. When claude/setup.sh sources this,
# it has already resolved and exported the same env — dot_export_env is idempotent.
dot_export_env
# if/fi, not `[[ ]] && x`: under `set -e` that list yields 1 when false, which
# becomes the script's exit status if it lands last.
if [[ "$DOT_ENV" == "work" ]]; then
	IS_WORK_ENV=1
else
	IS_WORK_ENV=0
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

	# Belt-and-braces: never operate on a target that resolves anywhere into
	# this repo. Checked BEFORE mkdir -p, and against the whole REPO_ROOT, not
	# just SKILLS_SOURCE: ~/.agents is a symlink to configs/agents, so the old
	# SKILLS_SOURCE-only test waved it through and mkdir created a bogus
	# configs/agents/skills/ full of links pointing back at configs/skills.
	# Returns non-zero (caller skips) rather than `fail`ing — one repo-resolving
	# target must not abort the projection into the other agent CLIs.
	local probe resolved
	probe=$([ -e "$target_dir" ] && echo "$target_dir" || dirname "$target_dir")
	resolved=$(realpath "$probe" 2>/dev/null || echo "$probe")
	if [[ "$resolved" == "$REPO_ROOT" || "$resolved" == "$REPO_ROOT"/* ]]; then
		info "Skipping skills projection: $target_dir resolves into the repo ($resolved)"
		return 1
	fi

	mkdir -p "$target_dir"
}

link_shared_skills() {
	local target_dir="$1"

	# Guard rejected this target (resolves into the repo) — skip it, don't abort.
	ensure_skill_dir "$target_dir" || return 0

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
