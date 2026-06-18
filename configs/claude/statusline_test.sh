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
# Strips SGR color codes AND OSC 8 hyperlink wrappers (\e]8;;url\a … \e]8;;\a)
strip_ansi() { sed $'s/\033\[[0-9;]*m//g; s/\033]8;;[^\007]*\007//g'; }

run_statusline() {
  # -u CLAUDE_EFFORT: the suite itself may run inside a Claude Code session
  # where that var is set; fixtures must control effort explicitly.
  echo "$1" | env -u CLAUDE_EFFORT bash "$STATUSLINE" 2>/dev/null
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

seed_pr_cache() {
  local cwd="$1" branch="$2" url="$3" state="$4" draft="$5" ci="${6:-}" review="${7:-}"
  local dir="/tmp/claude-statusline-pr-cache"
  mkdir -p "$dir"
  local key
  key=$(printf '%s:%s' "$cwd" "$branch" | md5 -q 2>/dev/null || printf '%s:%s' "$cwd" "$branch" | md5sum | cut -d' ' -f1)
  printf '%s\t%s\t%s\t%s' "$url" "$state" "$draft" "$review" >"$dir/$key"
  if [ -n "$ci" ]; then printf '%s' "$ci" >"$dir/${key}_ci"; fi
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
# Minimal valid input (Opus 4.8 1M context is the default hidden model)
INPUT_MINIMAL='{"model":{"display_name":"Claude Opus 4.8 (1M context)"},"cost":{"total_cost_usd":0,"total_duration_ms":0},"context_window":{"context_window_size":200000,"used_percentage":0}}'

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
assert_not_contains "hides default Opus 4.8 1M model name" "$out" "Opus"

out=$(run_statusline_plain "$INPUT_SONNET")
assert_contains "shows non-default model name" "$out" "Sonnet"

# Non-default Opus variants now show (only Opus 4.8 1M is hidden)
INPUT_OPUS_47='{"model":{"display_name":"Claude Opus 4.7"},"cost":{"total_cost_usd":0,"total_duration_ms":0},"context_window":{"context_window_size":200000,"used_percentage":0}}'
out=$(run_statusline_plain "$INPUT_OPUS_47")
assert_contains "shows Opus 4.7 (not the hidden 1M default)" "$out" "Opus 4.7"

# Fable 5 is NOT a hidden default — only Opus 4.8 1M is hidden
INPUT_FABLE='{"model":{"display_name":"Claude Fable 5"},"cost":{"total_cost_usd":0,"total_duration_ms":0},"context_window":{"context_window_size":200000,"used_percentage":0}}'
out=$(run_statusline_plain "$INPUT_FABLE")
assert_contains "shows Fable 5 (not a hidden default)" "$out" "Fable 5"

# Effort rides to the right of a shown model name
INPUT_MODEL_EFFORT='{"model":{"display_name":"Claude Opus 4.7"},"cost":{"total_cost_usd":0,"total_duration_ms":0},"context_window":{"used_percentage":0},"effortLevel":"high"}'
out_line1=$(run_statusline_plain "$INPUT_MODEL_EFFORT" | head -1)
assert_contains "effort glyph sits to the right of the model name" "$out_line1" "Opus 4.7 ◯ high"

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

# Smooth bar: eighth-blocks give sub-cell resolution (25% → 2 full + half block)
INPUT_QTR_CTX='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.50,"total_duration_ms":60000},"session_id":"test-qtr","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":25}}'
out=$(run_statusline_plain "$INPUT_QTR_CTX")
assert_contains "smooth bar renders partial block at 25%" "$out" "[██▌░░░░░░░] 25%"

# Absolute token count next to the % (from current_usage totals)
out=$(run_statusline_plain "$INPUT_FULL")
assert_contains "shows token count next to context pct" "$out" "70% (140k)"

out=$(run_statusline_plain "$INPUT_MINIMAL")
assert_not_contains "hides token count when usage is zero" "$out" "(0"

printf "\n\033[38;5;141m━━━ Uncommitted Lines (git diff vs HEAD) ━━━\033[0m\n"

# +/- now mirrors `git diff --shortstat HEAD` (uncommitted tracked changes),
# NOT the session edit counter — so it resets on commit. The high session
# counts in the JSON below must NOT appear; only the real git diff should.

# Dirty repo: appended lines → "+N" insertions, no deletions
LINES_ADD_REPO=$(mktemp -d -t statusline-lines.XXXXXX)
(cd "$LINES_ADD_REPO" && git init -q -b main && printf 'a\nb\n' >f.txt \
  && git add f.txt && git -c user.email=t@t -c user.name=t commit -q -m init \
  && printf 'a\nb\nc\nd\ne\n' >f.txt) >/dev/null
rm -rf /tmp/claude-statusline-git-cache /tmp/claude-statusline-pr-cache
LINES_ADD_INPUT='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.1,"total_duration_ms":1000,"total_lines_added":999,"total_lines_removed":888},"session_id":"lines-add","cwd":"'"$LINES_ADD_REPO"'","context_window":{"used_percentage":10}}'
out=$(run_statusline_plain "$LINES_ADD_INPUT")
assert_contains "shows uncommitted insertions from git diff" "$out" "+3"
assert_not_contains "ignores session lines_added" "$out" "+999"
assert_not_contains "no deletions when only insertions" "$out" "-888"

# Dirty repo: removed lines → "-N" deletions
LINES_DEL_REPO=$(mktemp -d -t statusline-lines.XXXXXX)
(cd "$LINES_DEL_REPO" && git init -q -b main && printf 'a\nb\nc\nd\n' >f.txt \
  && git add f.txt && git -c user.email=t@t -c user.name=t commit -q -m init \
  && printf 'a\nb\n' >f.txt) >/dev/null
rm -rf /tmp/claude-statusline-git-cache /tmp/claude-statusline-pr-cache
LINES_DEL_INPUT='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.1,"total_duration_ms":1000},"session_id":"lines-del","cwd":"'"$LINES_DEL_REPO"'","context_window":{"used_percentage":10}}'
out=$(run_statusline_plain "$LINES_DEL_INPUT")
assert_contains "shows uncommitted deletions from git diff" "$out" "-2"

# Clean repo: everything committed → no +/- even with session edits in JSON
LINES_CLEAN_REPO=$(mktemp -d -t statusline-lines.XXXXXX)
(cd "$LINES_CLEAN_REPO" && git init -q -b main && printf 'a\nb\n' >f.txt \
  && git add f.txt && git -c user.email=t@t -c user.name=t commit -q -m init) >/dev/null
rm -rf /tmp/claude-statusline-git-cache /tmp/claude-statusline-pr-cache
LINES_CLEAN_INPUT='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.1,"total_duration_ms":1000,"total_lines_added":50,"total_lines_removed":20},"session_id":"lines-clean","cwd":"'"$LINES_CLEAN_REPO"'","context_window":{"used_percentage":10}}'
out=$(run_statusline_plain "$LINES_CLEAN_INPUT")
assert_not_contains "hides lines on clean tree (added)" "$out" "+50"
assert_not_contains "hides lines on clean tree (deleted)" "$out" "-20"

rm -rf "$LINES_ADD_REPO" "$LINES_DEL_REPO" "$LINES_CLEAN_REPO"

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

printf "\n\033[38;5;141m━━━ Rate Limit Reset Countdown ━━━━━━━━━━━━━\033[0m\n"

# resets_at is documented as Unix epoch seconds; values are computed relative
# to now with a ~30s margin so a few seconds of test runtime can't flip them.
now_epoch=$(date +%s)
INPUT_RATE_RESET_HM='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":6.00,"total_duration_ms":3600000},"session_id":"test-reset-hm","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":45},"rate_limits":{"five_hour":{"used_percentage":85.3,"resets_at":'$((now_epoch + 4530))'},"seven_day":{"used_percentage":50}}}'
out=$(run_statusline_plain "$INPUT_RATE_RESET_HM")
assert_contains "shows reset countdown in h+m" "$out" "5h:85% 1h15m"

INPUT_RATE_RESET_M='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":6.00,"total_duration_ms":3600000},"session_id":"test-reset-m","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":45},"rate_limits":{"five_hour":{"used_percentage":85.3,"resets_at":'$((now_epoch + 1830))'},"seven_day":{"used_percentage":50}}}'
out=$(run_statusline_plain "$INPUT_RATE_RESET_M")
assert_contains "shows reset countdown in minutes" "$out" "5h:85% 30m"

INPUT_RATE_RESET_NOW='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":6.00,"total_duration_ms":3600000},"session_id":"test-reset-now","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":45},"rate_limits":{"five_hour":{"used_percentage":85.3,"resets_at":'$((now_epoch - 10))'},"seven_day":{"used_percentage":50}}}'
out=$(run_statusline_plain "$INPUT_RATE_RESET_NOW")
assert_contains "shows 'now' for past reset time" "$out" "5h:85% now"

INPUT_RATE_RESET_BAD='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":6.00,"total_duration_ms":3600000},"session_id":"test-reset-bad","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":45},"rate_limits":{"five_hour":{"used_percentage":85.3,"resets_at":"soon"},"seven_day":{"used_percentage":50}}}'
assert_exit_code "exits 0 with non-numeric resets_at" "$INPUT_RATE_RESET_BAD" 0
out=$(run_statusline_plain "$INPUT_RATE_RESET_BAD")
assert_contains "still shows rate pct when resets_at is malformed" "$out" "5h:85%"

printf "\n\033[38;5;141m━━━ Session Name ━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"

# Session name should be ignored — line 1 always shows project/repo/cwd basename
out=$(run_statusline_plain "$INPUT_SESSION_NAME")
assert_not_contains "session name does not appear in output" "$out" "refactor-auth"

# Pin cwd to the repo root (derived from this file's location, not $(pwd))
# so the suite passes no matter which directory it's invoked from.
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)
REPO_BASE=$(basename "$REPO_ROOT")
INPUT_SESSION_NAME_GIT='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.75,"total_duration_ms":180000},"session_id":"test-named-git","session_name":"refactor-auth","cwd":"'"$REPO_ROOT"'","context_window":{"context_window_size":200000,"used_percentage":20}}'
out_line1=$(run_statusline_plain "$INPUT_SESSION_NAME_GIT" | head -1)
assert_not_contains "session name does not replace project on line 1" "$out_line1" "refactor-auth"
assert_contains "cwd basename shown on line 1 even when session name set" "$out_line1" "$REPO_BASE"

printf "\n\033[38;5;141m━━━ Reasoning Effort ━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"

# Primary source: .effort.level (real Claude Code payload field, ≥2.1.133)
INPUT_EFFORT_REAL='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":1.00,"total_duration_ms":60000},"session_id":"test-eff-real","cwd":"/tmp","context_window":{"used_percentage":10},"effort":{"level":"high"}}'
out=$(run_statusline_plain "$INPUT_EFFORT_REAL")
assert_contains "shows effort.level (real payload field)" "$out" "◯ high"

# Legacy fallback key still honored
INPUT_EFFORT='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":1.00,"total_duration_ms":60000},"session_id":"test-eff","cwd":"/tmp","context_window":{"used_percentage":10},"effortLevel":"xhigh"}'
out=$(run_statusline_plain "$INPUT_EFFORT")
assert_contains "shows effortLevel when set" "$out" "xhigh"
assert_contains "shows effort indicator glyph" "$out" "◯"

# $CLAUDE_EFFORT env var fallback when the JSON carries no effort field
out=$(echo "$INPUT_FULL" | env CLAUDE_EFFORT=low bash "$STATUSLINE" 2>/dev/null | strip_ansi)
assert_contains "falls back to CLAUDE_EFFORT env var" "$out" "◯ low"

out=$(run_statusline_plain "$INPUT_FULL")
assert_not_contains "hides effort when key absent" "$out" "◯"

printf "\n\033[38;5;141m━━━ Light/Dark Background (COLORFGBG) ━━━━━━━\033[0m\n"

# Background detection swaps key-data + warning colors. We assert on the raw
# (un-stripped) ANSI so we can see which palette was chosen.
INPUT_BG='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":1.00,"total_duration_ms":60000},"session_id":"test-bg","cwd":"/tmp","context_window":{"used_percentage":10}}'

# Light bg (bg field = 15 → white background): key data is near-black (235)
out=$(echo "$INPUT_BG" | COLORFGBG="0;15" bash "$STATUSLINE" 2>/dev/null)
assert_contains "light bg uses near-black key data (235)" "$out" "38;5;235"
assert_not_contains "light bg drops near-white key data (255)" "$out" "38;5;255"

# bg field = 7 (silver) also counts as light
out=$(echo "$INPUT_BG" | COLORFGBG="0;7" bash "$STATUSLINE" 2>/dev/null)
assert_contains "silver bg (7) treated as light" "$out" "38;5;235"

# Dark bg (bg field = 0 → black background): key data stays near-white (255)
out=$(echo "$INPUT_BG" | COLORFGBG="15;0" bash "$STATUSLINE" 2>/dev/null)
assert_contains "dark bg keeps near-white key data (255)" "$out" "38;5;255"
assert_not_contains "dark bg avoids near-black key data (235)" "$out" "38;5;235"

# Unset COLORFGBG defaults to the dark palette
out=$(echo "$INPUT_BG" | env -u COLORFGBG bash "$STATUSLINE" 2>/dev/null)
assert_contains "unset COLORFGBG defaults to dark (255)" "$out" "38;5;255"

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

printf "\n\033[38;5;141m━━━ Long Name Truncation ━━━━━━━━━━━━━━━━━━━━\033[0m\n"

# Non-worktree long cwd: line 2 shows the path (trailing-truncated at 50 chars).
LONG_NAME="jordan-nes-3984-workflows-add-genetic-testing-decision-to-patient-list-and"
LONG_DIR=$(mktemp -d -t "statusline-longXXXXXX")
mkdir -p "$LONG_DIR/$LONG_NAME"
LONG_CWD="$LONG_DIR/$LONG_NAME"
INPUT_LONG_NAME='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0,"total_duration_ms":0},"session_id":"test-long","cwd":"'"$LONG_CWD"'","context_window":{"used_percentage":0}}'
out=$(run_statusline_plain "$INPUT_LONG_NAME")
line1=$(echo "$out" | head -1)
line2=$(echo "$out" | sed -n '2p')
assert_contains "truncates long project name at 30 chars" "$line1" "jordan-nes-3984-workflows-add-…"
assert_not_contains "full long name not present on line 1" "$line1" "$LONG_NAME"
assert_contains "truncates long cwd path fallback with trailing ellipsis" "$line2" "…"
assert_not_contains "full long path not present on line 2" "$line2" "$LONG_NAME"
assert_not_contains "cwd path keeps prefix (no leading ellipsis)" "$line2" "…-add-genetic"
rm -rf "$LONG_DIR"

# Worktree cwd WITHOUT git detection: path contains .worktrees/<name>, so line 2
# should collapse to ⎇ NAME (icon + name, no path prefix or .worktrees/ segment).
LONG_WT_ROOT=$(mktemp -d -t "statusline-wtpath.XXXXXX")
mkdir -p "$LONG_WT_ROOT/nest/.worktrees/$LONG_NAME"
LONG_WT_CWD="$LONG_WT_ROOT/nest/.worktrees/$LONG_NAME"
INPUT_LONG_WT='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0,"total_duration_ms":0},"session_id":"test-longwt","cwd":"'"$LONG_WT_CWD"'","context_window":{"used_percentage":0}}'
out=$(run_statusline_plain "$INPUT_LONG_WT")
line1=$(echo "$out" | head -1)
line2=$(echo "$out" | sed -n '2p')
assert_contains "line 1 shows inferred main repo name (nest)" "$line1" "nest"
assert_contains "line 2 shows worktree icon" "$line2" "⎇"
assert_not_contains "line 2 drops .worktrees/ path segment" "$line2" ".worktrees"
assert_not_contains "line 2 drops path prefix on the left" "$line2" "$LONG_WT_ROOT"
assert_contains "line 2 truncates long worktree name" "$line2" "…"
rm -rf "$LONG_WT_ROOT"

printf "\n\033[38;5;141m━━━ Worktree False-Positive ━━━━━━━━━━━━━━━━\033[0m\n"

# A plain (non-worktree) repo root must NOT be misflagged as a worktree.
# Regression: --git-dir returns relative ".git", which never equals the
# absolute --git-common-dir, so the repo was shown as "⎇ .git".
PLAIN_REPO=$(mktemp -d -t statusline-plain.XXXXXX)
(cd "$PLAIN_REPO" && git init -q -b main \
  && git -c user.email=t@t -c user.name=t commit --allow-empty -q -m init) >/dev/null
rm -rf /tmp/claude-statusline-git-cache /tmp/claude-statusline-pr-cache
out=$(run_statusline_plain '{"model":{"display_name":"x"},"cost":{"total_cost_usd":0},"cwd":"'"$PLAIN_REPO"'","context_window":{"used_percentage":5}}')
assert_not_contains "plain repo is not misflagged as a worktree" "$out" "⎇"
assert_contains "plain repo shows its branch" "$out" "main"
rm -rf "$PLAIN_REPO"

printf "\n\033[38;5;141m━━━ Base Branch Detection ━━━━━━━━━━━━━━━━━━\033[0m\n"

# Nearest-base heuristic: the base whose merge-base is fewest commits behind
# HEAD wins. Remote-tracking refs are simulated with git update-ref.

# Branch cut from main AFTER the release branch was cut → main is nearer.
BASE_REPO=$(mktemp -d -t statusline-base.XXXXXX)
(cd "$BASE_REPO" && git init -q -b main \
  && git -c user.email=t@t -c user.name=t commit --allow-empty -q -m A \
  && git update-ref refs/remotes/origin/release/2.15.0 HEAD \
  && git -c user.email=t@t -c user.name=t commit --allow-empty -q -m B \
  && git update-ref refs/remotes/origin/main HEAD \
  && git checkout -q -b jordan/from-main \
  && git -c user.email=t@t -c user.name=t commit --allow-empty -q -m C) >/dev/null
rm -rf /tmp/claude-statusline-git-cache /tmp/claude-statusline-pr-cache
INPUT_BASE_MAIN='{"model":{"display_name":"x"},"cost":{"total_cost_usd":0},"session_id":"test-base-main","cwd":"'"$BASE_REPO"'","context_window":{"used_percentage":5}}'
out=$(run_statusline_plain "$INPUT_BASE_MAIN")
assert_contains "branch cut from main shows main as base" "$out" "← main"
assert_not_contains "older release branch not picked as base" "$out" "release/2.15.0"
rm -rf "$BASE_REPO"

# Branch cut from the release tip (which is ahead of main) → release is nearer.
BASE_REPO2=$(mktemp -d -t statusline-base.XXXXXX)
(cd "$BASE_REPO2" && git init -q -b main \
  && git -c user.email=t@t -c user.name=t commit --allow-empty -q -m A \
  && git update-ref refs/remotes/origin/main HEAD \
  && git -c user.email=t@t -c user.name=t commit --allow-empty -q -m B \
  && git update-ref refs/remotes/origin/release/2.16.0 HEAD \
  && git checkout -q -b jordan/from-release \
  && git -c user.email=t@t -c user.name=t commit --allow-empty -q -m C) >/dev/null
rm -rf /tmp/claude-statusline-git-cache /tmp/claude-statusline-pr-cache
INPUT_BASE_REL='{"model":{"display_name":"x"},"cost":{"total_cost_usd":0},"session_id":"test-base-rel","cwd":"'"$BASE_REPO2"'","context_window":{"used_percentage":5}}'
out=$(run_statusline_plain "$INPUT_BASE_REL")
assert_contains "branch cut from release shows release as base" "$out" "← release/2.16.0"
rm -rf "$BASE_REPO2"

printf "\n\033[38;5;141m━━━ PR Badge + CI Glyph ━━━━━━━━━━━━━━━━━━━━\033[0m\n"

PR_REPO=$(mktemp -d -t statusline-pr.XXXXXX)
(cd "$PR_REPO" && git init -q -b jordan/pr-test \
  && git -c user.email=t@t -c user.name=t commit --allow-empty -q -m init) >/dev/null

rm -rf /tmp/claude-statusline-git-cache /tmp/claude-statusline-pr-cache
seed_pr_cache "$PR_REPO" "jordan/pr-test" "https://github.com/org/repo/pull/4567" "OPEN" "false" "✓"
INPUT_PR='{"model":{"display_name":"x"},"cost":{"total_cost_usd":0},"session_id":"test-pr","cwd":"'"$PR_REPO"'","context_window":{"used_percentage":5}}'
out=$(run_statusline_plain "$INPUT_PR")
assert_contains "open PR shows #number badge" "$out" "#4567"
assert_contains "open PR shows CI glyph next to badge" "$out" "#4567 ✓"

seed_pr_cache "$PR_REPO" "jordan/pr-test" "https://github.com/org/repo/pull/4567" "OPEN" "true" "⏳"
out=$(run_statusline_plain "$INPUT_PR")
assert_contains "draft PR shows draft suffix + CI glyph" "$out" "#4567 draft ⏳"

seed_pr_cache "$PR_REPO" "jordan/pr-test" "https://github.com/org/repo/pull/4567" "OPEN" "false" "✓" "APPROVED"
out=$(run_statusline_plain "$INPUT_PR")
assert_contains "approved PR shows approved suffix" "$out" "#4567 approved ✓"

seed_pr_cache "$PR_REPO" "jordan/pr-test" "https://github.com/org/repo/pull/4567" "OPEN" "false" "✗" "CHANGES_REQUESTED"
out=$(run_statusline_plain "$INPUT_PR")
assert_contains "changes-requested PR shows changes suffix" "$out" "#4567 changes ✗"

seed_pr_cache "$PR_REPO" "jordan/pr-test" "https://github.com/org/repo/pull/4567" "OPEN" "true" "" "APPROVED"
out=$(run_statusline_plain "$INPUT_PR")
assert_not_contains "draft PR hides review decision" "$out" "approved"

seed_pr_cache "$PR_REPO" "jordan/pr-test" "https://github.com/org/repo/pull/4567" "MERGED" "false"
out=$(run_statusline_plain "$INPUT_PR")
assert_contains "merged PR shows merged suffix" "$out" "#4567 merged"
assert_not_contains "merged PR hides stale CI glyph" "$out" "⏳"
rm -rf "$PR_REPO"

printf "\n\033[38;5;141m━━━ One-Line Mode ━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"

# Wide terminal: everything joins onto a single line
out=$(echo "$INPUT_FULL" | env -u CLAUDE_EFFORT STATUSLINE_ONE_LINE=1 STATUSLINE_COLS=300 bash "$STATUSLINE" 2>/dev/null | strip_ansi)
line_count=$(echo "$out" | wc -l | tr -d ' ')
if [ "$line_count" -eq 1 ]; then
  passed=$((passed + 1))
  printf "  \033[38;5;114m✓\033[0m one-line mode joins output when terminal is wide\n"
else
  failed=$((failed + 1))
  errors+="  FAIL: one-line mode joins output when terminal is wide — got $line_count lines\n"
  printf "  \033[38;5;203m✗\033[0m one-line mode joins output when terminal is wide (got %s lines)\n" "$line_count"
fi
# Project name ("tmp") is line-2 content; its presence proves line 2 was joined in.
assert_contains "one-line output keeps line-2 content" "$out" 'tmp'

# Narrow terminal: falls back to multi-line instead of overflowing
out=$(echo "$INPUT_FULL" | env -u CLAUDE_EFFORT STATUSLINE_ONE_LINE=1 STATUSLINE_COLS=40 bash "$STATUSLINE" 2>/dev/null | strip_ansi)
line_count=$(echo "$out" | wc -l | tr -d ' ')
if [ "$line_count" -gt 1 ]; then
  passed=$((passed + 1))
  printf "  \033[38;5;114m✓\033[0m one-line mode falls back to multi-line when too wide\n"
else
  failed=$((failed + 1))
  errors+="  FAIL: one-line mode falls back to multi-line when too wide — got $line_count line\n"
  printf "  \033[38;5;203m✗\033[0m one-line mode falls back to multi-line when too wide (got %s line)\n" "$line_count"
fi

# Unknown width (no override, no COLUMNS, no tty in test env): stays one-line
out=$(echo "$INPUT_FULL" | env -u CLAUDE_EFFORT -u COLUMNS STATUSLINE_ONE_LINE=1 bash "$STATUSLINE" 2>/dev/null | strip_ansi)
line_count=$(echo "$out" | wc -l | tr -d ' ')
if [ "$line_count" -eq 1 ]; then
  passed=$((passed + 1))
  printf "  \033[38;5;114m✓\033[0m one-line mode kept when terminal width is unknown\n"
else
  failed=$((failed + 1))
  errors+="  FAIL: one-line mode kept when terminal width is unknown — got $line_count lines\n"
  printf "  \033[38;5;203m✗\033[0m one-line mode kept when terminal width is unknown (got %s lines)\n" "$line_count"
fi

# Mode off: multi-line output unchanged
out=$(echo "$INPUT_FULL" | env -u CLAUDE_EFFORT -u STATUSLINE_ONE_LINE bash "$STATUSLINE" 2>/dev/null | strip_ansi)
line_count=$(echo "$out" | wc -l | tr -d ' ')
if [ "$line_count" -gt 1 ]; then
  passed=$((passed + 1))
  printf "  \033[38;5;114m✓\033[0m default multi-line output unaffected by one-line code\n"
else
  failed=$((failed + 1))
  errors+="  FAIL: default multi-line output unaffected — got $line_count line\n"
  printf "  \033[38;5;203m✗\033[0m default multi-line output unaffected (got %s line)\n" "$line_count"
fi

printf "\n\033[38;5;141m━━━ Node Apps (line 3) ━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"

# Cache stores plain "name:port" entries; the statusline wraps each in an
# OSC 8 link at display time — Nest frontend apps map to their https dev
# hostnames, everything else falls back to http://localhost:<port>.
NODE_TEST_CWD=$(mktemp -d "/tmp/statusline-test-node-XXXXXX")
mkdir -p /tmp/claude-statusline-node-cache
node_test_key=$(printf '%s' "$NODE_TEST_CWD" | md5 -q 2>/dev/null || printf '%s' "$NODE_TEST_CWD" | md5sum | cut -d' ' -f1)
printf 'client-api:3000 patient-navigator:3602 provider-portal:3601 yoda:3603' >"/tmp/claude-statusline-node-cache/${node_test_key}_node"
INPUT_NODE='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.10,"total_duration_ms":30000},"session_id":"test-node","cwd":"'"$NODE_TEST_CWD"'","context_window":{"context_window_size":200000,"used_percentage":3,"current_usage":{"input_tokens":5000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}'

out_raw=$(run_statusline "$INPUT_NODE")
out=$(printf '%s' "$out_raw" | strip_ansi)
assert_contains "shows app:port entries" "$out" 'client-api:3000 patient-navigator:3602 provider-portal:3601 yoda:3603'
assert_contains "yoda links to its https dev host" "$out_raw" ']8;;https://dev.yoda.nestgenomics.com:3603'
assert_contains "patient-navigator links to dev.app host" "$out_raw" ']8;;https://dev.app.nestgenomics.com:3602'
assert_contains "provider-portal links to dev.portal host" "$out_raw" ']8;;https://dev.portal.nestgenomics.com:3601'
assert_contains "unmapped app falls back to localhost link" "$out_raw" ']8;;http://localhost:3000'
assert_not_contains "link URL adds no visible text" "$out" 'nestgenomics.com'

rm -rf "$NODE_TEST_CWD" "/tmp/claude-statusline-node-cache/${node_test_key}_node"

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
