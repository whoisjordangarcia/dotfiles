#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

TEST_HOME=$(mktemp -d)
trap 'rm -rf "$TEST_HOME"' EXIT

fail() {
	echo "FAIL $*" >&2
	exit 1
}

FARMS=(.claude/skills .cursor/skills .codex/skills)

seed_home() {
	rm -rf "$TEST_HOME"
	mkdir -p "$TEST_HOME/.claude/skills/hand-installed" "$TEST_HOME/.cursor/skills" "$TEST_HOME/external/example"
	echo "# x" >"$TEST_HOME/.claude/skills/hand-installed/SKILL.md"
	ln -s "$TEST_HOME/external/example" "$TEST_HOME/.cursor/skills/external-example"
	ln -s "$TEST_HOME/nowhere" "$TEST_HOME/.cursor/skills/gone"
}

run_setup() {
	env -u WORK_ENV HOME="$TEST_HOME" DOT_ENVIRONMENT="$1" "$REPO_ROOT/script/skills/setup.sh" >/dev/null 2>&1 ||
		fail "setup.sh exited non-zero in $1 mode"
}

seed_home
run_setup work
echo "✓ setup.sh runs to completion (portable find)"

[ -f "$TEST_HOME/.agents/skills/nest-linear-beta/SKILL.md" ] || fail "nest-linear-beta not copied in work mode"
for farm in "${FARMS[@]}"; do
	[ -f "$TEST_HOME/$farm/nest-linear-beta/SKILL.md" ] || fail "$farm/nest-linear-beta not linked in work mode"
done
[ -e "$TEST_HOME/.agents/skills/win11-vm" ] && fail "personal-only win11-vm synced in work mode"
[ -L "$TEST_HOME/.claude/skills/win11-vm" ] && fail "personal-only win11-vm linked in work mode"
echo "✓ work mode syncs nest-* skills into every farm; personal-only skills skipped"

[ -f "$TEST_HOME/.claude/skills/hand-installed/SKILL.md" ] || fail "hand-installed real skill dir was deleted"
[ -L "$TEST_HOME/.cursor/skills/external-example" ] || fail "external link was deleted"
[ -L "$TEST_HOME/.cursor/skills/gone" ] && fail "dangling link survived"
echo "✓ prune removes dangling links only; real dirs and external links survive"

run_setup personal
[ -e "$TEST_HOME/.agents/skills/nest-linear-beta" ] && fail "nest-linear-beta kept in personal mode"
for farm in "${FARMS[@]}"; do
	[ -L "$TEST_HOME/$farm/nest-linear-beta" ] && fail "$farm/nest-linear-beta link kept in personal mode"
done
[ -f "$TEST_HOME/.claude/skills/win11-vm/SKILL.md" ] || fail "win11-vm missing in personal mode"
echo "✓ switching to personal removes nest-* skills; personal-only skills synced"

echo "All skills setup tests passed"
