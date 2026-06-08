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

mkdir -p "$TEST_HOME/.cursor/skills" "$TEST_HOME/external-skills/example"
ln -s "$TEST_HOME/external-skills/example" "$TEST_HOME/.cursor/skills/external-example"

mkdir -p "$TEST_HOME/.legacy-claude-skills"
ln -s "$TEST_HOME/.legacy-claude-skills" "$TEST_HOME/.claude-skills-link"
mkdir -p "$TEST_HOME/.claude"
ln -s "$TEST_HOME/.claude-skills-link" "$TEST_HOME/.claude/skills"

HOME="$TEST_HOME" LOG_LEVEL=error DOT_SYMLINK_MODE=override "$REPO_ROOT/script/skills/setup.sh" >/dev/null 2>&1

for agent_dir in "$TEST_HOME/.claude/skills" "$TEST_HOME/.cursor/skills" "$TEST_HOME/.codex/skills" "$TEST_HOME/.agents/skills"; do
	assert_directory "$agent_dir"
	assert_symlink_to "$agent_dir/agent-browser" "$REPO_ROOT/configs/skills/agent-browser"
	assert_symlink_to "$agent_dir/nest-linear-beta" "$REPO_ROOT/configs/skills/nest-linear-beta"
done

assert_symlink_to "$TEST_HOME/.claude/skills" "$TEST_HOME/.claude-skills-link"
assert_symlink_to "$TEST_HOME/.cursor/skills/external-example" "$TEST_HOME/external-skills/example"

echo "All skills setup tests passed"
