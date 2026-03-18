#!/bin/bash
# statusline_demo.sh — visual demo of all statusline variations
# Run: bash configs/claude/statusline_demo.sh
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
STATUSLINE="$SCRIPT_DIR/statusline.sh"
DEMO_DIR=$(mktemp -d "/tmp/statusline-demo-XXXXXX")

cleanup() { rm -rf "$DEMO_DIR" /tmp/claude-statusline-sessions/demo-* /tmp/claude-statusline-git-cache /tmp/claude-statusline-pr-cache /tmp/claude-statusline-docker-cache; }
trap cleanup EXIT

sep=" \033[38;5;245m·\033[0m "
header() { printf '\n\033[38;5;141m━━━ %s ━━━\033[0m\n\n' "$1"; }
expect() { printf '\033[38;5;245m   expect │ %s\033[0m\n' "$1"; }
actual_prefix() { printf '\033[38;5;255m   actual │ \033[0m'; }

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
  printf '%s\t%s\t%s' "$url" "$state" "$draft" >"$dir/$key"
  if [ -n "$ci" ]; then printf '%s' "$ci" >"$dir/${key}_ci"; fi
}

# ─── Helper: clear git caches so each demo is fresh ─────────────
clear_caches() {
  rm -rf /tmp/claude-statusline-git-cache
  rm -rf /tmp/claude-statusline-pr-cache
  rm -rf /tmp/claude-statusline-docker-cache
}

run() {
  local output
  output=$(echo "$1" | bash "$STATUSLINE" 2>/dev/null)
  local first=true
  while IFS= read -r line; do
    if [ "$first" = true ]; then
      printf '\033[38;5;255m   actual │ \033[0m%b\n' "$line"
      first=false
    else
      printf '          \033[38;5;245m│\033[0m %b\n' "$line"
    fi
  done <<<"$output"
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

# ─── 11. Docker containers (worktree) ────────────────────────────
clear_caches
mkdir -p /tmp/claude-statusline-docker-cache
wt_docker_key=$(printf '%s' "wt-jordan-preview-pr" | md5 -q 2>/dev/null || printf '%s' "wt-jordan-preview-pr" | md5sum | cut -d' ' -f1)
printf '\033[38;5;114m🐳 postgres:5432,redis:6379\033[0m' >"/tmp/claude-statusline-docker-cache/$wt_docker_key"
set_pr_cache "$WT1" "jordan/preview-pr" "https://github.com/Nest-Genomics/nest/pull/4567" "OPEN" "false" $'\033[38;5;114m✓\033[0m'

header "11. Worktree with Docker containers"
expect "line 3: 🐳 postgres:5432,redis:6379"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":1.80},"session_id":"demo-11","cwd":"'"$WT1"'","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":60000,"cache_creation_input_tokens":5000,"cache_read_input_tokens":20000}}}'

# ─── 12. Node apps listening on ports ────────────────────────────
clear_caches
mkdir -p /tmp/claude-statusline-docker-cache
node_key=$(printf '%s' "jordan-preview-pr" | md5 -q 2>/dev/null || printf '%s' "jordan-preview-pr" | md5sum | cut -d' ' -f1)
printf '\033[38;5;114m⬡ client-api:3000,provider-portal:4200\033[0m' >"/tmp/claude-statusline-docker-cache/${node_key}_node"
set_pr_cache "$WT1" "jordan/preview-pr" "https://github.com/Nest-Genomics/nest/pull/4567" "OPEN" "false" $'\033[38;5;114m✓\033[0m'

header "12. Worktree with Node apps"
expect "line 3: ⬡ client-api:3000,provider-portal:4200"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.95},"session_id":"demo-12","cwd":"'"$WT1"'","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":40000,"cache_creation_input_tokens":3000,"cache_read_input_tokens":12000}}}'

# ─── 13. Docker + Node combined ──────────────────────────────────
clear_caches
mkdir -p /tmp/claude-statusline-docker-cache
printf '\033[38;5;114m🐳 postgres:5432\033[0m' >"/tmp/claude-statusline-docker-cache/$wt_docker_key"
printf '\033[38;5;114m⬡ client-api:3000\033[0m' >"/tmp/claude-statusline-docker-cache/${node_key}_node"
set_pr_cache "$WT1" "jordan/preview-pr" "https://github.com/Nest-Genomics/nest/pull/4567" "OPEN" "false" $'\033[38;5;114m✓\033[0m'

header "13. Docker + Node combined (full 3-line output)"
expect "line 3: 🐳 postgres:5432 · ⬡ client-api:3000"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":3.20},"session_id":"demo-13","cwd":"'"$WT1"'","cost":{"total_cost_usd":3.20,"total_lines_added":156,"total_lines_removed":43},"context_window":{"context_window_size":200000,"current_usage":{"input_tokens":100000,"cache_creation_input_tokens":8000,"cache_read_input_tokens":35000}}}'

# ─── 14. Dirty tree with sync status ────────────────────────────
clear_caches
mkdir -p /tmp/claude-statusline-git-cache
dirty_key=$(printf '%s' "$REPO1" | md5 -q 2>/dev/null || printf '%s' "$REPO1" | md5sum | cut -d' ' -f1)
# Fake dirty status: 2 staged, 3 modified, 1 new
printf '\033[38;5;114m● 2 staged\033[0m \033[38;5;255m◦ 3 modified\033[0m \033[38;5;245m+1 new\033[0m' >"/tmp/claude-statusline-git-cache/${dirty_key}_dirty"
# Fake sync: 2 ahead, 1 behind
printf '\033[38;5;255m↑2\033[0m \033[38;5;255m↓1\033[0m' >"/tmp/claude-statusline-git-cache/${dirty_key}_sync"

header "14. Dirty tree with sync status"
expect "main · ↑2 ↓1 · ● 2 staged ◦ 3 modified +1 new"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.45},"session_id":"demo-14","cwd":"'"$REPO1"'","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":30000,"cache_creation_input_tokens":2000,"cache_read_input_tokens":10000}}}'

# ─── 15. CI failure on open PR ───────────────────────────────────
clear_caches
set_pr_cache "$WT1" "jordan/preview-pr" "https://github.com/Nest-Genomics/nest/pull/4567" "OPEN" "false" $'\033[38;5;203m✗\033[0m'

header "15. Open PR with CI failure"
expect "⎇ #4567 · 🌿 jordan/preview-pr · #4567 ✗"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":1.10},"session_id":"demo-15","cwd":"'"$WT1"'","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":70000,"cache_creation_input_tokens":5000,"cache_read_input_tokens":22000}}}'

# ─── 16. Closed PR ──────────────────────────────────────────────
clear_caches
set_pr_cache "$WT1" "jordan/preview-pr" "https://github.com/Nest-Genomics/nest/pull/4567" "CLOSED" "false"

header "16. Closed PR"
expect "⎇ #4567 · 🌿 jordan/preview-pr · #4567 closed"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.30},"session_id":"demo-16","cwd":"'"$WT1"'","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":20000,"cache_creation_input_tokens":1000,"cache_read_input_tokens":5000}}}'

# ─── 17. Cost rate (long session, >5min) ─────────────────────────
clear_caches
mkdir -p /tmp/claude-statusline-sessions
# Fake a session that started 45 minutes ago
echo $(($(date +%s) - 2700)) >"/tmp/claude-statusline-sessions/demo-17"

header "17. Long session with cost rate"
expect "\$4.50 (\$6.00/hr) · 45m"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":4.50},"session_id":"demo-17","cwd":"/tmp","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":150000,"cache_creation_input_tokens":12000,"cache_read_input_tokens":60000}}}'

# ─── 18. Long branch name truncation ────────────────────────────
clear_caches
REPO4="$DEMO_DIR/myapp"
make_repo "$REPO4" "jordan/NES-12345-super-long-feature-branch-name-that-exceeds-the-limit"

header "18. Long branch name (truncated at 45 chars)"
expect "jordan/NES-12345-super-long-feature-branch-n…"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.15},"session_id":"demo-18","cwd":"'"$REPO4"'","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":8000,"cache_creation_input_tokens":500,"cache_read_input_tokens":2000}}}'

printf '\033[38;5;141m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n'
printf '\033[38;5;114m✓ Demo complete — %d variations shown\033[0m\n\n' 18
