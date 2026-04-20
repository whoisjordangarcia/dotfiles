#!/bin/bash
# statusline_test.sh — regression tests for the Claude Code statusline script
# Run: bash configs/claude/statusline_test.sh
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
STATUSLINE="$SCRIPT_DIR/statusline.sh"

passed=0
failed=0
errors=""

# ─── Helpers ────────────────────────────────────────────────────────
strip_ansi() { sed $'s/\033\[[0-9;]*m//g'; }

run_statusline() {
  echo "$1" | bash "$STATUSLINE" 2>/dev/null
}

run_statusline_plain() {
  run_statusline "$1" | strip_ansi
}

assert_contains() {
  local test_name="$1" output="$2" expected="$3"
  if echo "$output" | grep -qF -- "$expected"; then
    passed=$((passed + 1))
    printf "  \033[38;5;114m✓\033[0m %s\n" "$test_name"
  else
    failed=$((failed + 1))
    errors+="  FAIL: $test_name — expected to contain: '$expected'\n"
    printf "  \033[38;5;203m✗\033[0m %s\n" "$test_name"
    printf "    expected to contain: %s\n" "$expected"
    printf "    got: %s\n" "$output"
  fi
}

assert_not_contains() {
  local test_name="$1" output="$2" unexpected="$3"
  if ! echo "$output" | grep -qF -- "$unexpected"; then
    passed=$((passed + 1))
    printf "  \033[38;5;114m✓\033[0m %s\n" "$test_name"
  else
    failed=$((failed + 1))
    errors+="  FAIL: $test_name — expected NOT to contain: '$unexpected'\n"
    printf "  \033[38;5;203m✗\033[0m %s\n" "$test_name"
    printf "    expected NOT to contain: %s\n" "$unexpected"
  fi
}

assert_exit_code() {
  local test_name="$1" input="$2" expected_code="$3"
  local actual_code
  echo "$input" | bash "$STATUSLINE" >/dev/null 2>&1
  actual_code=$?
  if [ "$actual_code" -eq "$expected_code" ]; then
    passed=$((passed + 1))
    printf "  \033[38;5;114m✓\033[0m %s\n" "$test_name"
  else
    failed=$((failed + 1))
    errors+="  FAIL: $test_name — expected exit $expected_code, got $actual_code\n"
    printf "  \033[38;5;203m✗\033[0m %s (expected %d, got %d)\n" "$test_name" "$expected_code" "$actual_code"
  fi
}

# ─── Test fixtures ──────────────────────────────────────────────────
# Minimal valid input (Opus 4.7 is the default hidden model)
INPUT_MINIMAL='{"model":{"display_name":"Claude Opus 4.7"},"cost":{"total_cost_usd":0,"total_duration_ms":0},"context_window":{"context_window_size":200000,"used_percentage":0}}'

# Full input (non-git cwd so we skip git/PR paths)
INPUT_FULL='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":1.23,"total_duration_ms":120000,"total_lines_added":42,"total_lines_removed":7},"session_id":"test-sess","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":70,"current_usage":{"input_tokens":80000,"cache_creation_input_tokens":10000,"cache_read_input_tokens":50000}}}'

# Sonnet model (should show model name since it's not Opus)
INPUT_SONNET='{"model":{"display_name":"Claude 3.7 Sonnet"},"cost":{"total_cost_usd":0.50,"total_duration_ms":60000},"context_window":{"context_window_size":200000,"used_percentage":3,"current_usage":{"input_tokens":5000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}'

# High context usage (>80%) — session_id required to prevent bash read field collapse
INPUT_HIGH_CTX='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":5.00,"total_duration_ms":600000},"session_id":"test-hi","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":92,"current_usage":{"input_tokens":170000,"cache_creation_input_tokens":10000,"cache_read_input_tokens":5000}}}'

# Medium context usage (50-80%)
INPUT_MED_CTX='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":2.00,"total_duration_ms":300000},"session_id":"test-med","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":62,"current_usage":{"input_tokens":110000,"cache_creation_input_tokens":10000,"cache_read_input_tokens":5000}}}'

# No lines changed
INPUT_NO_LINES='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.10,"total_duration_ms":30000},"session_id":"test-nol","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":3,"current_usage":{"input_tokens":5000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}'

# Sonnet with session_id (for field alignment)
INPUT_SONNET_FULL='{"model":{"display_name":"Claude 3.7 Sonnet"},"cost":{"total_cost_usd":0.50,"total_duration_ms":60000},"session_id":"test-son","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":3,"current_usage":{"input_tokens":5000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}'

# Rate limits — critical (5h ≥ 70% and 7d ≥ 80% both surface)
INPUT_RATE_HIGH='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":8.00,"total_duration_ms":3600000},"session_id":"test-rate-hi","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":45},"rate_limits":{"five_hour":{"used_percentage":85.3},"seven_day":{"used_percentage":88.0}}}'

# Rate limits — low usage (both below thresholds; statusline should stay quiet)
INPUT_RATE_LOW='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.50,"total_duration_ms":600000},"session_id":"test-rate-lo","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":10},"rate_limits":{"five_hour":{"used_percentage":12.0},"seven_day":{"used_percentage":5.4}}}'

# No rate limits (API key user)
INPUT_NO_RATE='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":1.00,"total_duration_ms":120000},"session_id":"test-no-rate","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":15}}'

# Session name
INPUT_SESSION_NAME='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.75,"total_duration_ms":180000},"session_id":"test-named","session_name":"refactor-auth","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":20}}'

# Empty/null JSON
INPUT_EMPTY='{}'

# ─── Tests ──────────────────────────────────────────────────────────
printf "\n\033[38;5;141m━━━ Exit Code ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"

assert_exit_code "exits 0 with minimal input" "$INPUT_MINIMAL" 0
assert_exit_code "exits 0 with full input" "$INPUT_FULL" 0
assert_exit_code "exits 0 with empty JSON" "$INPUT_EMPTY" 0
assert_exit_code "exits 0 with non-git cwd" "$INPUT_NO_LINES" 0

printf "\n\033[38;5;141m━━━ Cost Display ━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"

out=$(run_statusline_plain "$INPUT_MINIMAL")
assert_contains "shows zero cost" "$out" '$0.00'

out=$(run_statusline_plain "$INPUT_FULL")
assert_contains "shows formatted cost" "$out" '$1.23'

printf "\n\033[38;5;141m━━━ Model Name ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"

out=$(run_statusline_plain "$INPUT_MINIMAL")
assert_not_contains "hides Opus model name" "$out" "Opus"

out=$(run_statusline_plain "$INPUT_SONNET")
assert_contains "shows non-Opus model name" "$out" "Sonnet"

printf "\n\033[38;5;141m━━━ Context Bar ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"

out=$(run_statusline_plain "$INPUT_MINIMAL")
assert_contains "shows context percentage" "$out" "0%"
assert_contains "shows bar brackets" "$out" "["

out=$(run_statusline_plain "$INPUT_HIGH_CTX")
assert_contains "shows high context %" "$out" "92%"
assert_contains "shows warning emoji at >80%" "$out" "⚠️"

out=$(run_statusline_plain "$INPUT_MED_CTX")
assert_contains "shows medium context %" "$out" "62%"
assert_not_contains "no warning emoji at 50-80%" "$out" "⚠️"

printf "\n\033[38;5;141m━━━ Lines Changed ━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"

out=$(run_statusline_plain "$INPUT_FULL")
assert_contains "shows lines added" "$out" "+42"
assert_contains "shows lines removed" "$out" "-7"

out=$(run_statusline_plain "$INPUT_NO_LINES")
assert_not_contains "hides lines when zero" "$out" "+"
assert_not_contains "hides lines when zero" "$out" "-"

printf "\n\033[38;5;141m━━━ Cache Hit Rate ━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"

out=$(run_statusline_plain "$INPUT_FULL")
# 50000 cache_read / 140000 total = 35% — below 80%, so it shows
assert_contains "shows cache rate when below 80%" "$out" "⚡"

out=$(run_statusline_plain "$INPUT_NO_LINES")
assert_not_contains "hides cache when zero reads" "$out" "⚡"

printf "\n\033[38;5;141m━━━ Fallback CWD (no git) ━━━━━━━━━━━━━━━━━━\033[0m\n"

out=$(run_statusline_plain "$INPUT_FULL")
assert_contains "shows project name when no git" "$out" "tmp"

printf "\n\033[38;5;141m━━━ Rate Limits ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"

out=$(run_statusline_plain "$INPUT_RATE_HIGH")
assert_contains "shows 5h rate at ≥70%" "$out" "5h:85%"
assert_contains "shows 7d rate at ≥80%" "$out" "7d:88%"

out=$(run_statusline_plain "$INPUT_RATE_LOW")
assert_not_contains "hides 5h rate below 70%" "$out" "5h:"
assert_not_contains "hides 7d rate below 80%" "$out" "7d:"

out=$(run_statusline_plain "$INPUT_NO_RATE")
assert_not_contains "hides rate limits when absent" "$out" "5h:"
assert_not_contains "hides 7d when absent" "$out" "7d:"

printf "\n\033[38;5;141m━━━ Session Name ━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"

out=$(run_statusline_plain "$INPUT_SESSION_NAME")
assert_contains "shows session name as project" "$out" "refactor-auth"

# Session name in a git repo should not show cwd basename on line 1
INPUT_SESSION_NAME_GIT='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.75,"total_duration_ms":180000},"session_id":"test-named-git","session_name":"refactor-auth","cwd":"'"$(pwd)"'","context_window":{"context_window_size":200000,"used_percentage":20}}'
out_line1=$(run_statusline_plain "$INPUT_SESSION_NAME_GIT" | head -1)
assert_contains "session name replaces project on line 1" "$out_line1" "refactor-auth"
assert_not_contains "cwd basename hidden when session name set" "$out_line1" "dotfiles"

printf "\n\033[38;5;141m━━━ Reasoning Effort ━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"

# Effort is pulled directly from the statusline JSON payload.
INPUT_EFFORT='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":1.00,"total_duration_ms":60000},"session_id":"test-eff","cwd":"/tmp","context_window":{"used_percentage":10},"effortLevel":"xhigh"}'
out=$(run_statusline_plain "$INPUT_EFFORT")
assert_contains "shows effortLevel when set" "$out" "xhigh"
assert_contains "shows effort indicator glyph" "$out" "◯"

out=$(run_statusline_plain "$INPUT_FULL")
assert_not_contains "hides effort when key absent" "$out" "◯"

printf "\n\033[38;5;141m━━━ Worktree/Branch Dedup ━━━━━━━━━━━━━━━━━━\033[0m\n"

# Fresh worktree repo where wt dir name matches branch (slash → dash)
WT_REPO=$(mktemp -d -t statusline-wt.XXXXXX)
(cd "$WT_REPO" && git init -q -b main && git -c user.email=t@t -c user.name=t commit --allow-empty -q -m init \
  && git checkout -q -b jordan/preview-pr \
  && git checkout -q -b main-tmp \
  && mkdir -p .claude/worktrees \
  && git worktree add -q .claude/worktrees/jordan-preview-pr jordan/preview-pr) >/dev/null

rm -rf /tmp/claude-statusline-git-cache /tmp/claude-statusline-pr-cache
WT_MATCH_INPUT='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.1,"total_duration_ms":1000},"session_id":"wt-match","cwd":"'"$WT_REPO"'/.claude/worktrees/jordan-preview-pr","context_window":{"used_percentage":10}}'
out=$(run_statusline_plain "$WT_MATCH_INPUT")
assert_contains "shows branch for matching worktree" "$out" "jordan/preview-pr"
assert_not_contains "suppresses ⎇ label when wt ≈ branch" "$out" "⎇ jordan-preview-pr"

# Differing worktree dir vs branch → ⎇ label stays
WT_REPO2=$(mktemp -d -t statusline-wt.XXXXXX)
(cd "$WT_REPO2" && git init -q -b main && git -c user.email=t@t -c user.name=t commit --allow-empty -q -m init \
  && git checkout -q -b placeholder \
  && mkdir -p .claude/worktrees \
  && git worktree add -q -b feature/big-refactor .claude/worktrees/quick-test HEAD) >/dev/null

rm -rf /tmp/claude-statusline-git-cache /tmp/claude-statusline-pr-cache
WT_DIFF_INPUT='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.1,"total_duration_ms":1000},"session_id":"wt-diff","cwd":"'"$WT_REPO2"'/.claude/worktrees/quick-test","context_window":{"used_percentage":10}}'
out=$(run_statusline_plain "$WT_DIFF_INPUT")
assert_contains "shows ⎇ label when wt name differs" "$out" "⎇ quick-test"
assert_contains "shows branch alongside ⎇ label" "$out" "feature/big-refactor"

rm -rf "$WT_REPO" "$WT_REPO2"

printf "\n\033[38;5;141m━━━ Output Structure ━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"

line_count=$(run_statusline_plain "$INPUT_FULL" | wc -l | tr -d ' ')
if [ "$line_count" -ge 1 ] && [ "$line_count" -le 3 ]; then
  passed=$((passed + 1))
  printf "  \033[38;5;114m✓\033[0m outputs 1-3 lines (got %s)\n" "$line_count"
else
  failed=$((failed + 1))
  printf "  \033[38;5;203m✗\033[0m outputs 1-3 lines (got %s)\n" "$line_count"
fi

out_empty=$(run_statusline_plain "$INPUT_EMPTY")
if [ -n "$out_empty" ]; then
  passed=$((passed + 1))
  printf "  \033[38;5;114m✓\033[0m produces output even with empty JSON\n"
else
  failed=$((failed + 1))
  printf "  \033[38;5;203m✗\033[0m produces output even with empty JSON\n"
fi

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
