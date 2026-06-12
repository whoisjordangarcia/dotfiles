#!/bin/bash
# cmux_pr_test.sh — regression tests for cmux-pr.py's review-pill mapping.
# Exercises the pure `review_pill` logic via the script's `--emit` mode
# (no cmux socket, no network). Run: bash configs/claude/scripts/cmux_pr_test.sh
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PR="$SCRIPT_DIR/cmux-pr.py"

passed=0
failed=0
errors=""

assert_eq() {
  local test_name="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then
    passed=$((passed + 1))
    printf "  \033[38;5;114m✓\033[0m %s\n" "$test_name"
  else
    failed=$((failed + 1))
    errors+="  FAIL: $test_name\n    want: $want\n    got:  $got\n"
    printf "  \033[38;5;203m✗\033[0m %s\n" "$test_name"
    printf "    want: %s\n    got:  %s\n" "$want" "$got"
  fi
}

emit() { python3 "$PR" --emit "$@"; }

printf "\n\033[38;5;141mcmux-pr.py review-pill mapping\033[0m\n"

assert_eq "APPROVED with number -> set green pill" \
  "$(emit APPROVED 5)" $'set\t✓ Approved #5\t#3FB950\t20'

assert_eq "APPROVED without number -> set, no #" \
  "$(emit APPROVED '')" $'set\t✓ Approved\t#3FB950\t20'

assert_eq "CHANGES_REQUESTED -> clear" \
  "$(emit CHANGES_REQUESTED 5)" "clear"

assert_eq "REVIEW_REQUIRED -> clear" \
  "$(emit REVIEW_REQUIRED 5)" "clear"

assert_eq "empty decision (no reviews) -> clear" \
  "$(emit '' 5)" "clear"

# ─── Summary ────────────────────────────────────────────────────────
total=$((passed + failed))
printf "\n\033[38;5;141m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
if [ "$failed" -eq 0 ]; then
  printf "\033[38;5;114m✓ All %d tests passed\033[0m\n\n" "$total"
else
  printf "\033[38;5;203m✗ %d/%d tests failed\033[0m\n" "$failed" "$total"
  printf "\n%b\n" "$errors"
  exit 1
fi
