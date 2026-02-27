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
# Minimal valid input
INPUT_MINIMAL='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0},"context_window":{"context_window_size":200000}}'

# Full input (non-git cwd so we skip git/PR paths)
INPUT_FULL='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":1.23,"total_lines_added":42,"total_lines_removed":7},"session_id":"test-sess","cwd":"/tmp","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":80000,"cache_creation_input_tokens":10000,"cache_read_input_tokens":50000}}}'

# Sonnet model (should show model name since it's not Opus)
INPUT_SONNET='{"model":{"display_name":"Claude 3.7 Sonnet"},"cost":{"total_cost_usd":0.50},"context_window":{"context_window_size":200000,"current_usage":{"input_tokens":5000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}'

# High context usage (>80%) — session_id required to prevent bash read field collapse
INPUT_HIGH_CTX='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":5.00},"session_id":"test-hi","cwd":"/tmp","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":170000,"cache_creation_input_tokens":10000,"cache_read_input_tokens":5000}}}'

# Medium context usage (50-80%)
INPUT_MED_CTX='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":2.00},"session_id":"test-med","cwd":"/tmp","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":110000,"cache_creation_input_tokens":10000,"cache_read_input_tokens":5000}}}'

# No lines changed
INPUT_NO_LINES='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.10},"session_id":"test-nol","cwd":"/tmp","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":5000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}'

# Sonnet with session_id (for field alignment)
INPUT_SONNET_FULL='{"model":{"display_name":"Claude 3.7 Sonnet"},"cost":{"total_cost_usd":0.50},"session_id":"test-son","cwd":"/tmp","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":5000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}'

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
assert_contains "shows written label" "$out" "written"

out=$(run_statusline_plain "$INPUT_NO_LINES")
assert_not_contains "hides lines when zero" "$out" "written"

printf "\n\033[38;5;141m━━━ Cache Hit Rate ━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"

out=$(run_statusline_plain "$INPUT_FULL")
# 50000 cache_read / 140000 total = 35% — below 80%, so it shows
assert_contains "shows cache rate when below 80%" "$out" "⚡"

out=$(run_statusline_plain "$INPUT_NO_LINES")
assert_not_contains "hides cache when zero reads" "$out" "⚡"

printf "\n\033[38;5;141m━━━ Fallback CWD (no git) ━━━━━━━━━━━━━━━━━━\033[0m\n"

out=$(run_statusline_plain "$INPUT_FULL")
assert_contains "shows project name when no git" "$out" "tmp"

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
