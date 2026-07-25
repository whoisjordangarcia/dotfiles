#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

TEST_HOME=$(mktemp -d)
cleanup() {
	rm -rf "$TEST_HOME"
}
trap cleanup EXIT

assert_symlink_to() {
	local link_path="$1"
	local expected_target="$2"

	if [ ! -L "$link_path" ]; then
		echo "FAIL expected symlink: $link_path" >&2
		exit 1
	fi

	local actual_target
	actual_target=$(readlink "$link_path")
	if [ "$actual_target" != "$expected_target" ]; then
		echo "FAIL $link_path points to $actual_target, expected $expected_target" >&2
		exit 1
	fi
}

assert_directory() {
	local dir="$1"
	if [ ! -d "$dir" ]; then
		echo "FAIL expected directory: $dir" >&2
		exit 1
	fi
}

assert_real_directory() {
	local dir="$1"
	assert_directory "$dir"
	if [ -L "$dir" ]; then
		echo "FAIL expected a real directory, got a symlink: $dir" >&2
		exit 1
	fi
}

assert_absent() {
	local path="$1"
	if [ -e "$path" ] || [ -L "$path" ]; then
		echo "FAIL expected nothing at: $path" >&2
		exit 1
	fi
}

AGENT_DIRS=(.claude/skills .cursor/skills .codex/skills .agents/skills)

# Seed the fixture: an unrelated external skill link that must survive, plus the
# legacy layout where the whole skills dir was itself a symlink into the repo.
seed_home() {
	rm -rf "$TEST_HOME"
	mkdir -p "$TEST_HOME/.cursor/skills" "$TEST_HOME/external-skills/example" "$TEST_HOME/.claude"
	ln -s "$TEST_HOME/external-skills/example" "$TEST_HOME/.cursor/skills/external-example"
	mkdir -p "$TEST_HOME/.legacy-claude-skills"
	ln -s "$TEST_HOME/.legacy-claude-skills" "$TEST_HOME/.claude-skills-link"
	ln -s "$TEST_HOME/.claude-skills-link" "$TEST_HOME/.claude/skills"
}

# Work mode: everything is projected, nest-* included.
seed_home
env -u DOT_ENVIRONMENT HOME="$TEST_HOME" WORK_ENV=1 LOG_LEVEL=error \
	DOT_SYMLINK_MODE=override "$REPO_ROOT/script/skills/setup.sh" >/dev/null 2>&1

for agent_dir in "${AGENT_DIRS[@]}"; do
	assert_directory "$TEST_HOME/$agent_dir"
	assert_symlink_to "$TEST_HOME/$agent_dir/agent-browser" "$REPO_ROOT/configs/skills/agent-browser"
	assert_symlink_to "$TEST_HOME/$agent_dir/nest-linear-beta" "$REPO_ROOT/configs/skills/nest-linear-beta"
done
echo "✓ work mode links shared and nest-* skills into every agent dir"

# The legacy whole-dir symlink must be DISSOLVED into a real directory: per-skill
# links through it would resolve back into the repo and clobber the sources.
assert_real_directory "$TEST_HOME/.claude/skills"
echo "✓ legacy whole-dir symlink replaced with a real directory"

assert_symlink_to "$TEST_HOME/.cursor/skills/external-example" "$TEST_HOME/external-skills/example"
echo "✓ unrelated external skill links are left alone"

# Personal mode: nest-* must not be projected at all.
seed_home
env -u WORK_ENV HOME="$TEST_HOME" DOT_ENVIRONMENT=personal LOG_LEVEL=error \
	DOT_SYMLINK_MODE=override "$REPO_ROOT/script/skills/setup.sh" >/dev/null 2>&1

for agent_dir in "${AGENT_DIRS[@]}"; do
	assert_symlink_to "$TEST_HOME/$agent_dir/agent-browser" "$REPO_ROOT/configs/skills/agent-browser"
	assert_absent "$TEST_HOME/$agent_dir/nest-linear-beta"
done
echo "✓ personal mode installs shared skills and no nest-* skills"

# ...and a machine flipped work → personal gets its stale nest-* links pruned.
env -u DOT_ENVIRONMENT HOME="$TEST_HOME" WORK_ENV=1 LOG_LEVEL=error \
	DOT_SYMLINK_MODE=override "$REPO_ROOT/script/skills/setup.sh" >/dev/null 2>&1
assert_symlink_to "$TEST_HOME/.claude/skills/nest-linear-beta" "$REPO_ROOT/configs/skills/nest-linear-beta"
env -u WORK_ENV HOME="$TEST_HOME" DOT_ENVIRONMENT=personal LOG_LEVEL=error \
	DOT_SYMLINK_MODE=override "$REPO_ROOT/script/skills/setup.sh" >/dev/null 2>&1
assert_absent "$TEST_HOME/.claude/skills/nest-linear-beta"
echo "✓ switching work → personal prunes stale nest-* links"

echo "All skills setup tests passed"
