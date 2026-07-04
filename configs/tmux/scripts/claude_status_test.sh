#!/usr/bin/env bash
# Regression tests for claude_status.sh (pure --classify / --render hooks;
# no tmux server needed).
# Run: bash configs/tmux/scripts/claude_status_test.sh
set -u

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
SUT="$SCRIPT_DIR/claude_status.sh"

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

classify() { bash "$SUT" --classify; }

# --- classify_screen --------------------------------------------------------

assert_eq "approval prompt classifies as waiting" \
    "waiting" "$(printf 'Bash command\n\nDo you want to proceed?\n❯ 1. Yes\n' | classify)"

assert_eq "continue prompt classifies as waiting" \
    "waiting" "$(printf 'Do you want to continue?\n' | classify)"

assert_eq "spinner footer classifies as churning" \
    "churning" "$(printf 'Thinking…\nesc to interrupt\n' | classify)"

assert_eq "thinking footer classifies as churning" \
    "churning" "$(printf 'ctrl-t for thinking\n' | classify)"

assert_eq "plain prompt screen classifies as idle" \
    "idle" "$(printf 'Welcome to Claude Code\n> \n' | classify)"

assert_eq "waiting beats churning on the same screen" \
    "waiting" "$(printf 'esc to interrupt\nDo you want to proceed?\n' | classify)"

# Stale approval text scrolled above the last 15 lines must not count
stale=$(printf 'Do you want to proceed?\n%s' "$(yes 'output line' | head -20)")
assert_eq "stale prompt above last 15 lines classifies as idle" \
    "idle" "$(printf '%s\n' "$stale" | classify)"

# --- render_state -----------------------------------------------------------

assert_eq "waiting renders amber filled dot" \
    '#[fg=#fab387,bold]●#[default] ' "$(bash "$SUT" --render waiting)"

assert_eq "churning renders green filled dot" \
    '#[fg=#a6e3a1,bold]●#[default] ' "$(bash "$SUT" --render churning)"

assert_eq "idle renders dim hollow dot" \
    '#[fg=colour245]○#[default] ' "$(bash "$SUT" --render idle)"

assert_eq "none renders nothing" \
    "" "$(bash "$SUT" --render none)"

# --- entrypoint guard --------------------------------------------------------

assert_eq "no session id outputs nothing" \
    "" "$(bash "$SUT")"

echo
if [ "$FAIL" -eq 0 ]; then
    echo "All $PASS tests passed"
    exit 0
else
    echo "$FAIL of $((PASS + FAIL)) tests failed"
    exit 1
fi
