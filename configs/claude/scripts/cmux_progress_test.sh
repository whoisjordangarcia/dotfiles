#!/bin/bash
# cmux_progress_test.sh — regression tests for cmux-progress.py's todos->bar map.
# Exercises the pure `progress_for` logic via the script's `--emit` mode (reads a
# todos JSON array on stdin). Run: bash configs/claude/scripts/cmux_progress_test.sh
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PROG="$SCRIPT_DIR/cmux-progress.py"

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

emit() { printf '%s' "$1" | python3 "$PROG" --emit; }

printf "\n\033[38;5;141mcmux-progress.py todos->bar mapping\033[0m\n"

assert_eq "empty list -> clear" \
  "$(emit '[]')" "clear"

assert_eq "all pending -> 0.00, label = first pending activeForm" \
  "$(emit '[{"content":"A","activeForm":"Doing A","status":"pending"},{"content":"B","status":"pending"}]')" \
  $'set\t0.00\tDoing A'

assert_eq "1 of 3 done, 1 in_progress -> 0.33, in_progress label" \
  "$(emit '[{"content":"A","status":"completed"},{"content":"B","activeForm":"Building B","status":"in_progress"},{"content":"C","status":"pending"}]')" \
  $'set\t0.33\tBuilding B'

assert_eq "in_progress without activeForm -> falls back to content" \
  "$(emit '[{"content":"Raw content","status":"in_progress"}]')" \
  $'set\t0.00\tRaw content'

assert_eq "all complete -> 1.00, label Done" \
  "$(emit '[{"content":"A","status":"completed"},{"content":"B","status":"completed"}]')" \
  $'set\t1.00\tDone'

assert_eq "multiple in_progress -> takes the first" \
  "$(emit '[{"content":"A","activeForm":"First","status":"in_progress"},{"content":"B","activeForm":"Second","status":"in_progress"}]')" \
  $'set\t0.00\tFirst'

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
