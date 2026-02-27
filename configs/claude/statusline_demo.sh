#!/bin/bash
# statusline_demo.sh — visual demo of all statusline variations
# Run: bash configs/claude/statusline_demo.sh
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
STATUSLINE="$SCRIPT_DIR/statusline.sh"
DEMO_DIR=$(mktemp -d "/tmp/statusline-demo-XXXXXX")

cleanup() { rm -rf "$DEMO_DIR" /tmp/claude-statusline-sessions/demo-*; }
trap cleanup EXIT

sep=" \033[38;5;245m·\033[0m "
header() { printf '\n\033[38;5;141m━━━ %s ━━━\033[0m\n' "$1"; }
expect() { printf '\033[38;5;245m   expected: %s\033[0m\n' "$1"; }

# ─── Helper: create a git repo with a commit ────────────────────
make_repo() {
	local dir="$1" branch="${2:-main}"
	mkdir -p "$dir" && cd "$dir"
	git init -q -b "$branch"
	git config user.email "demo@test.com"
	git config user.name "Demo"
	git commit --allow-empty -m "init" -q
}

# ─── Helper: pre-populate PR cache ──────────────────────────────
set_pr_cache() {
	local cwd="$1" branch="$2" url="$3" state="$4" draft="$5"
	local ci="${6:-}"
	local dir="/tmp/claude-statusline-pr-cache"
	mkdir -p "$dir"
	local key=$(printf '%s:%s' "$cwd" "$branch" | md5 -q 2>/dev/null || printf '%s:%s' "$cwd" "$branch" | md5sum | cut -d' ' -f1)
	printf '%s\t%s\t%s' "$url" "$state" "$draft" > "$dir/$key"
	if [ -n "$ci" ]; then printf '%s' "$ci" > "$dir/${key}_ci"; fi
}

# ─── Helper: clear git caches so each demo is fresh ─────────────
clear_caches() {
	rm -rf /tmp/claude-statusline-git-cache
	rm -rf /tmp/claude-statusline-pr-cache
}

run() {
	echo "$1" | bash "$STATUSLINE" 2>/dev/null
	echo ""
}

# ═════════════════════════════════════════════════════════════════
printf '\n\033[38;5;255;1m  Statusline Variation Demo\033[0m\n'
# ═════════════════════════════════════════════════════════════════

# ─── 1. Normal repo ─────────────────────────────────────────────
clear_caches
REPO1="$DEMO_DIR/dotfiles"
make_repo "$REPO1"

header "1. Normal repo (no worktree)"
expect "dotfiles · 🌿 main"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.23},"session_id":"demo-1","cwd":"'"$REPO1"'","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":40000,"cache_creation_input_tokens":2000,"cache_read_input_tokens":8000}}}'

# ─── 2. Normal repo with lines changed ──────────────────────────
clear_caches
header "2. Normal repo with lines changed"
expect "dotfiles · 🌿 main · +42 -7 written"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":1.23},"session_id":"demo-2","cwd":"'"$REPO1"'","cost":{"total_cost_usd":1.23,"total_lines_added":42,"total_lines_removed":7},"context_window":{"context_window_size":200000,"current_usage":{"input_tokens":80000,"cache_creation_input_tokens":10000,"cache_read_input_tokens":50000}}}'

# ─── 3. Worktree, name ≈ branch (slash/dash) ────────────────────
clear_caches
REPO2="$DEMO_DIR/nest"
make_repo "$REPO2"
# Create the branch, then switch main back so worktree can use it
git checkout -q -b jordan/preview-pr
git checkout -q -b main-tmp
mkdir -p "$REPO2/.claude/worktrees"
git worktree add -q "$REPO2/.claude/worktrees/jordan-preview-pr" jordan/preview-pr
WT1="$REPO2/.claude/worktrees/jordan-preview-pr"

header "3. Worktree, no PR, name ≈ branch (slash→dash)"
expect "nest · 🌿 jordan/preview-pr"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":1.45},"session_id":"demo-3","cwd":"'"$WT1"'","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":60000,"cache_creation_input_tokens":5000,"cache_read_input_tokens":20000}}}'

# ─── 4. Worktree with open PR ───────────────────────────────────
clear_caches
set_pr_cache "$WT1" "jordan/preview-pr" "https://github.com/Nest-Genomics/nest/pull/4567" "OPEN" "false" $'\033[38;5;114m✓\033[0m'

header "4. Worktree with open PR #4567 + CI pass"
expect "nest · ⎇ #4567 · 🌿 jordan/preview-pr"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":2.31},"session_id":"demo-4","cwd":"'"$WT1"'","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":110000,"cache_creation_input_tokens":10000,"cache_read_input_tokens":30000}}}'

# ─── 5. Worktree with draft PR ──────────────────────────────────
clear_caches
set_pr_cache "$WT1" "jordan/preview-pr" "https://github.com/Nest-Genomics/nest/pull/4567" "OPEN" "true" $'\033[38;5;221m⏳\033[0m'

header "5. Worktree with draft PR #4567 + CI pending"
expect "nest · ⎇ #4567 · 🌿 jordan/preview-pr · #4567 draft ⏳"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.87},"session_id":"demo-5","cwd":"'"$WT1"'","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":50000,"cache_creation_input_tokens":3000,"cache_read_input_tokens":15000}}}'

# ─── 6. Worktree with merged PR ─────────────────────────────────
clear_caches
set_pr_cache "$WT1" "jordan/preview-pr" "https://github.com/Nest-Genomics/nest/pull/4567" "MERGED" "false"

header "6. Worktree with merged PR #4567 (purple)"
expect "nest · ⎇ #4567 · 🌿 jordan/preview-pr"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":3.10},"session_id":"demo-6","cwd":"'"$WT1"'","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":90000,"cache_creation_input_tokens":8000,"cache_read_input_tokens":25000}}}'

# ─── 7. Worktree with different name, no PR ──────────────────────
clear_caches
# Create a separate repo for this variation to avoid branch conflicts
REPO3="$DEMO_DIR/nest2"
make_repo "$REPO3"
git checkout -q -b placeholder-branch
mkdir -p "$REPO3/.claude/worktrees"
git worktree add -q -b feature/big-refactor "$REPO3/.claude/worktrees/quick-test" HEAD
WT2="$REPO3/.claude/worktrees/quick-test"
set_pr_cache "$WT2" "feature/big-refactor" "" "" ""

header "7. Worktree, no PR, name differs from branch"
expect "nest2 · ⎇ quick-test · 🌿 feature/big-refactor"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.05},"session_id":"demo-6","cwd":"'"$WT2"'","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":10000,"cache_creation_input_tokens":1000,"cache_read_input_tokens":2000}}}'

# ─── 8. Non-git directory ────────────────────────────────────────
clear_caches
header "8. Non-git directory (/tmp)"
expect "tmp"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.10},"session_id":"demo-8","cwd":"/tmp","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":5000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}'

# ─── 9. Sonnet model + high context ─────────────────────────────
clear_caches
header "9. Sonnet model + high context (92%) + warning"
expect "Sonnet 3.7 · \$5.00 · ... · [█████████░] 92% ⚠️"
run '{"model":{"display_name":"Claude 3.7 Sonnet"},"cost":{"total_cost_usd":5.00},"session_id":"demo-9","cwd":"/tmp","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":170000,"cache_creation_input_tokens":10000,"cache_read_input_tokens":5000}}}'

# ─── 10. Medium context (yellow zone) ────────────────────────────
clear_caches
header "10. Medium context (62%) — yellow bar"
expect "[██████░░░░] 62%"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":2.00},"session_id":"demo-10","cwd":"/tmp","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":110000,"cache_creation_input_tokens":10000,"cache_read_input_tokens":5000}}}'

printf '\033[38;5;141m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n'
printf '\033[38;5;114m✓ Demo complete — %d variations shown\033[0m\n\n' 10
