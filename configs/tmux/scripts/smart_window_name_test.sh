#!/usr/bin/env bash
# Regression tests for smart_window_name.sh
# Run: bash configs/tmux/scripts/smart_window_name_test.sh
set -u

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
SUT="$SCRIPT_DIR/smart_window_name.sh"

PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "✓ $desc"
        PASS=$((PASS + 1))
    else
        echo "✗ $desc"
        echo "    expected: '$expected'"
        echo "    actual:   '$actual'"
        FAIL=$((FAIL + 1))
    fi
}

# Sandbox: a fake dev root with git repos inside, selected via DEV_ROOTS
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export DEV_ROOTS="$TMP/dev"

make_repo() {
    mkdir -p "$1"
    git -C "$1" init -q
}

make_repo "$TMP/dev/myproject"
make_repo "$TMP/dev/jordan-worktree-fix"
make_repo "$TMP/dev/a-repository-with-a-very-long-name"
mkdir -p "$TMP/other/downloads"

run() { bash "$SUT" "$@"; }

# Shell in a dev-root git repo → repo name
assert_eq "shell in dev repo shows repo name" \
    "myproject" "$(run "$TMP/dev/myproject" zsh "")"

# jordan- worktree prefix is stripped
assert_eq "jordan- prefix stripped from worktree name" \
    "worktree-fix" "$(run "$TMP/dev/jordan-worktree-fix" zsh "")"

# Shell outside dev roots → directory basename
assert_eq "shell outside dev roots falls back to basename" \
    "downloads" "$(run "$TMP/other/downloads" zsh "")"

# Non-shell command in a dev repo → cmd:repo
assert_eq "command in dev repo shows cmd:repo" \
    "nvim:myproject" "$(run "$TMP/dev/myproject" nvim "")"

# Non-shell command outside dev roots → cmd only (git must not be consulted)
assert_eq "command outside dev roots shows cmd only" \
    "htop" "$(run "$TMP/other/downloads" htop "")"

# Claude Code reports its version number as the process name
assert_eq "version-string command resolves to claude" \
    "claude:myproject" "$(run "$TMP/dev/myproject" "2.1.72" "")"

# Names longer than 25 chars truncate with ellipsis
long_name=$(run "$TMP/dev/a-repository-with-a-very-long-name" zsh "")
assert_eq "long repo name truncated to 25 chars with ellipsis" \
    "a-repository-with-a-very…" "$long_name"

# node with no child process falls back to plain "node"
assert_eq "node with no resolvable child stays node" \
    "node:myproject" "$(run "$TMP/dev/myproject" node "99999999")"

echo
if [ "$FAIL" -eq 0 ]; then
    echo "All $PASS tests passed"
    exit 0
else
    echo "$FAIL of $((PASS + FAIL)) tests failed"
    exit 1
fi
