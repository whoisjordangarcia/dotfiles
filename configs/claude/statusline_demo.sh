#!/bin/bash
# statusline_demo.sh — visual demo of all statusline variations
# Run: bash configs/claude/statusline_demo.sh
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
STATUSLINE="$SCRIPT_DIR/statusline.sh"
DEMO_DIR=$(mktemp -d "/tmp/statusline-demo-XXXXXX")

cleanup() { rm -rf "$DEMO_DIR" /tmp/claude-statusline-git-cache /tmp/claude-statusline-pr-cache /tmp/claude-statusline-node-cache; }
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
  local ci="${6:-}" review="${7:-}"
  local dir="/tmp/claude-statusline-pr-cache"
  mkdir -p "$dir"
  local key=$(printf '%s:%s' "$cwd" "$branch" | md5 -q 2>/dev/null || printf '%s:%s' "$cwd" "$branch" | md5sum | cut -d' ' -f1)
  printf '%s\t%s\t%s\t%s' "$url" "$state" "$draft" "$review" >"$dir/$key"
  if [ -n "$ci" ]; then printf '%s' "$ci" >"$dir/${key}_ci"; fi
}

# ─── Helper: clear git caches so each demo is fresh ─────────────
clear_caches() {
  rm -rf /tmp/claude-statusline-git-cache
  rm -rf /tmp/claude-statusline-pr-cache
  rm -rf /tmp/claude-statusline-node-cache
}

run() {
  # Older demo fixtures used Opus 4.6 as the implicit/default model. Keep those
  # scenarios focused on their feature by normalizing them to today's hidden default.
  local input="${1//Claude Opus 4.6/Claude Opus 4.8 (1M context)}"
  local output
  # -u CLAUDE_EFFORT: keep scenarios deterministic when the demo itself runs
  # inside a Claude Code session that exports the effort env var.
  # STATUSLINE_COLS=200: pin a wide pane so these scenarios show full output
  # regardless of the demo terminal's width (narrow-pane shedding/clamping has
  # its own dedicated section below).
  output=$(echo "$input" | env -u CLAUDE_EFFORT STATUSLINE_COLS=200 bash "$STATUSLINE" 2>/dev/null)
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
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.23,"total_duration_ms":120000},"session_id":"demo-1","cwd":"'"$REPO1"'","context_window":{"context_window_size":200000,"used_percentage":25,"current_usage":{"input_tokens":40000,"cache_creation_input_tokens":2000,"cache_read_input_tokens":8000}}}'

# ─── 2. Repo with uncommitted changes (+/- = git diff vs HEAD) ──
clear_caches
REPO_DIRTY="$DEMO_DIR/webapp"
make_repo "$REPO_DIRTY"
# Commit a file, then leave uncommitted edits → git diff --shortstat HEAD = +4 -2.
# The session counts in the JSON (42/7) are intentionally ignored now.
(cd "$REPO_DIRTY" && printf '1\n2\n3\n4\n5\n' >work.txt && git add work.txt \
  && git commit -q -m base && printf '1\n2\n3\nA\nB\nC\nD\n' >work.txt)
header "2. Repo with uncommitted changes (+/- mirrors git diff, resets on commit)"
expect "webapp · 🌿 main · +4 -2"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":1.23,"total_duration_ms":300000,"total_lines_added":42,"total_lines_removed":7},"session_id":"demo-2","cwd":"'"$REPO_DIRTY"'","context_window":{"context_window_size":200000,"used_percentage":70,"current_usage":{"input_tokens":80000,"cache_creation_input_tokens":10000,"cache_read_input_tokens":50000}}}'

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
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":1.45,"total_duration_ms":480000},"session_id":"demo-3","cwd":"'"$WT1"'","context_window":{"context_window_size":200000,"used_percentage":43,"current_usage":{"input_tokens":60000,"cache_creation_input_tokens":5000,"cache_read_input_tokens":20000}}}'

# ─── 4. Worktree with open PR ───────────────────────────────────
clear_caches
set_pr_cache "$WT1" "jordan/preview-pr" "https://github.com/Nest-Genomics/nest/pull/4567" "OPEN" "false" $'\033[38;5;114m✓\033[0m' "APPROVED"

header "4. Worktree with open PR #4567, approved + CI pass"
expect "L2: ⎇ #4567 approved ✓ jordan/preview-pr"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":2.31,"total_duration_ms":900000},"session_id":"demo-4","cwd":"'"$WT1"'","context_window":{"context_window_size":200000,"used_percentage":75,"current_usage":{"input_tokens":110000,"cache_creation_input_tokens":10000,"cache_read_input_tokens":30000}}}'

# ─── 5. Worktree with draft PR ──────────────────────────────────
clear_caches
set_pr_cache "$WT1" "jordan/preview-pr" "https://github.com/Nest-Genomics/nest/pull/4567" "OPEN" "true" $'\033[38;5;221m⏳\033[0m'

header "5. Worktree with draft PR #4567 + CI pending"
expect "L2: ⎇ #4567 draft ⏳ jordan/preview-pr"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.87,"total_duration_ms":240000},"session_id":"demo-5","cwd":"'"$WT1"'","context_window":{"context_window_size":200000,"used_percentage":34,"current_usage":{"input_tokens":50000,"cache_creation_input_tokens":3000,"cache_read_input_tokens":15000}}}'

# ─── 6. Worktree with merged PR ─────────────────────────────────
clear_caches
set_pr_cache "$WT1" "jordan/preview-pr" "https://github.com/Nest-Genomics/nest/pull/4567" "MERGED" "false"

header "6. Worktree with merged PR #4567 (purple)"
expect "L2: ⎇ #4567 merged jordan/preview-pr"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":3.10,"total_duration_ms":1200000},"session_id":"demo-6","cwd":"'"$WT1"'","context_window":{"context_window_size":200000,"used_percentage":62,"current_usage":{"input_tokens":90000,"cache_creation_input_tokens":8000,"cache_read_input_tokens":25000}}}'

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
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.05,"total_duration_ms":60000},"session_id":"demo-6","cwd":"'"$WT2"'","context_window":{"context_window_size":200000,"used_percentage":7,"current_usage":{"input_tokens":10000,"cache_creation_input_tokens":1000,"cache_read_input_tokens":2000}}}'

# ─── 8. Non-git directory ────────────────────────────────────────
clear_caches
header "8. Non-git directory (/tmp)"
expect "tmp"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.10,"total_duration_ms":30000},"session_id":"demo-8","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":3,"current_usage":{"input_tokens":5000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}'

# ─── 9. Sonnet model + high context ─────────────────────────────
clear_caches
header "9. Sonnet model + high context (92%) + warning"
expect "Sonnet 3.7 · \$5.00 · ... · [█████████▏] 92% (185k) ⚠️"
run '{"model":{"display_name":"Claude 3.7 Sonnet"},"cost":{"total_cost_usd":5.00,"total_duration_ms":1800000},"session_id":"demo-9","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":92,"current_usage":{"input_tokens":170000,"cache_creation_input_tokens":10000,"cache_read_input_tokens":5000}}}'

# ─── 10. Medium context (yellow zone) ────────────────────────────
clear_caches
header "10. Medium context (62%) — yellow bar, smooth eighth-block edge"
expect "[██████▏░░░] 62% (125k)"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":2.00,"total_duration_ms":600000},"session_id":"demo-10","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":62,"current_usage":{"input_tokens":110000,"cache_creation_input_tokens":10000,"cache_read_input_tokens":5000}}}'

# ─── 11. Node apps listening on ports (line 3) ───────────────────
clear_caches
mkdir -p /tmp/claude-statusline-node-cache
node_key=$(printf '%s' "$WT1" | md5 -q 2>/dev/null || printf '%s' "$WT1" | md5sum | cut -d' ' -f1)
# Cache holds plain entries; the statusline renders color + clickable OSC 8
# links at display time — Nest frontend apps map to their https dev hostnames
# (yoda → dev.yoda…, patient-navigator → dev.app…, provider-portal →
# dev.portal…), anything else links to http://localhost:<port>.
printf 'client-api:3000 provider-portal:4200' >"/tmp/claude-statusline-node-cache/${node_key}_node"
set_pr_cache "$WT1" "jordan/preview-pr" "https://github.com/Nest-Genomics/nest/pull/4567" "OPEN" "false" $'\033[38;5;114m✓\033[0m'

header "11. Worktree with running Node apps (line 3)"
expect "L2: ⎇ #4567 ✓ jordan/preview-pr"
expect "L3: client-api:3000 provider-portal:4200  (clickable: localhost / dev.portal.nestgenomics.com)"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.95,"total_duration_ms":360000},"session_id":"demo-11","cwd":"'"$WT1"'","context_window":{"context_window_size":200000,"used_percentage":28,"current_usage":{"input_tokens":40000,"cache_creation_input_tokens":3000,"cache_read_input_tokens":12000}}}'

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
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.45,"total_duration_ms":180000},"session_id":"demo-14","cwd":"'"$REPO1"'","context_window":{"context_window_size":200000,"used_percentage":21,"current_usage":{"input_tokens":30000,"cache_creation_input_tokens":2000,"cache_read_input_tokens":10000}}}'

# ─── 15. CI failure on open PR ───────────────────────────────────
clear_caches
set_pr_cache "$WT1" "jordan/preview-pr" "https://github.com/Nest-Genomics/nest/pull/4567" "OPEN" "false" $'\033[38;5;203m✗\033[0m'

header "15. Open PR with CI failure"
expect "L2: ⎇ #4567 ✗ jordan/preview-pr"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":1.10,"total_duration_ms":420000},"session_id":"demo-15","cwd":"'"$WT1"'","context_window":{"context_window_size":200000,"used_percentage":49,"current_usage":{"input_tokens":70000,"cache_creation_input_tokens":5000,"cache_read_input_tokens":22000}}}'

# ─── 16. Closed PR ──────────────────────────────────────────────
clear_caches
set_pr_cache "$WT1" "jordan/preview-pr" "https://github.com/Nest-Genomics/nest/pull/4567" "CLOSED" "false"

header "16. Closed PR"
expect "L2: ⎇ #4567 closed jordan/preview-pr"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.30,"total_duration_ms":90000},"session_id":"demo-16","cwd":"'"$WT1"'","context_window":{"context_window_size":200000,"used_percentage":13,"current_usage":{"input_tokens":20000,"cache_creation_input_tokens":1000,"cache_read_input_tokens":5000}}}'

# ─── 17. Cost rate (long session, >5min) ─────────────────────────
clear_caches

header "17. Long session with cost rate"
expect "\$4.50 (\$6.00/hr) · 45m"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":4.50,"total_duration_ms":2700000},"session_id":"demo-17","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":85,"current_usage":{"input_tokens":150000,"cache_creation_input_tokens":12000,"cache_read_input_tokens":60000}}}'

# ─── 18. Long branch name truncation ────────────────────────────
clear_caches
REPO4="$DEMO_DIR/myapp"
make_repo "$REPO4" "jordan/NES-12345-super-long-feature-branch-name-that-exceeds-the-limit"

header "18. Long branch name (truncated at 45 chars)"
expect "jordan/NES-12345-super-long-feature-branch-na…"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.15,"total_duration_ms":45000},"session_id":"demo-18","cwd":"'"$REPO4"'","context_window":{"context_window_size":200000,"used_percentage":5,"current_usage":{"input_tokens":8000,"cache_creation_input_tokens":500,"cache_read_input_tokens":2000}}}'

# ─── 19. Rate limits — low usage (dim) ──────────────────────────
clear_caches
header "19. Rate limits — low usage (hidden below thresholds)"
expect "no 5h/7d indicators (5h < 70%, 7d < 80%)"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.50,"total_duration_ms":600000},"session_id":"demo-19","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":10},"rate_limits":{"five_hour":{"used_percentage":12.0},"seven_day":{"used_percentage":5.4}}}'

# ─── 20. Rate limits — high usage (yellow/red) ─────────────────
clear_caches
header "20. Rate limits — 5h critical, 7d below threshold"
expect "5h:85% (red); 7d:62% hidden (< 80%)"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":8.00,"total_duration_ms":3600000},"session_id":"demo-20","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":45},"rate_limits":{"five_hour":{"used_percentage":85.3},"seven_day":{"used_percentage":62.1}}}'

# ─── 21. Rate limits — critical (both red) ─────────────────────
clear_caches
header "21. Rate limits — critical (both red)"
expect "5h:95% 7d:88%"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":12.00,"total_duration_ms":7200000},"session_id":"demo-21","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":78},"rate_limits":{"five_hour":{"used_percentage":95.0},"seven_day":{"used_percentage":88.0}}}'

# ─── 22. Session name ──────────────────────────────────────────
clear_caches
header "22. Session name (ignored — cwd basename always wins)"
expect "tmp on L1, no refactor-auth anywhere"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.75,"total_duration_ms":180000},"session_id":"demo-22","session_name":"refactor-auth","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":20}}'

# ─── 23. No rate limits (API key user) ─────────────────────────
clear_caches
header "23. No rate limits (API key user — should not show 5h/7d)"
expect "no rate limit indicators"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":1.00,"total_duration_ms":120000},"session_id":"demo-23","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":15}}'

# ─── 19. Long worktree name truncation ─────────────────────────
clear_caches
REPO5="$DEMO_DIR/nest3"
make_repo "$REPO5"
git checkout -q -b jordan-nes-4331-bug-yoda-deep-links-ignore-url-account-and-redirect-to-first
git checkout -q -b main-tmp2
mkdir -p "$REPO5/.claude/worktrees"
git worktree add -q "$REPO5/.claude/worktrees/jordan-nes-4331-bug-yoda-deep-links-ignore-url-account-and-redirect-to-first" jordan-nes-4331-bug-yoda-deep-links-ignore-url-account-and-redirect-to-first
WT3="$REPO5/.claude/worktrees/jordan-nes-4331-bug-yoda-deep-links-ignore-url-account-and-redirect-to-first"

header "19. Long worktree name (branch == dir → ⎇ deduped, branch truncated at 45 chars)"
expect "L1: nest3 · \$0.00 · 0s · [░░░░░░░░░░] 0%"
expect "L2: jordan-nes-4331-bug-yoda-deep-links-ignore-ur… · just now"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.00},"session_id":"demo-19","cwd":"'"$WT3"'","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}'

# ─── 24. Reasoning effort indicator ─────────────────────────────
clear_caches
header "24. Reasoning effort (.effort.level from statusline JSON)"
expect "L1: xhigh · tmp · \$0.25 · ..."
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.25,"total_duration_ms":60000},"session_id":"demo-24","cwd":"/tmp","context_window":{"used_percentage":12},"effort":{"level":"xhigh"}}'

# ─── 25. Long project name + cwd path truncation ────────────────
clear_caches
LONG_NAME_DEMO="jordan-nes-3984-workflows-add-genetic-testing-decision-to-patient-list-and"
LONG_DIR_DEMO="$DEMO_DIR/$LONG_NAME_DEMO"
mkdir -p "$LONG_DIR_DEMO"
header "25. Long project name (30-char cap) + non-worktree cwd path (50-char trailing …)"
expect "L1: jordan-nes-3984-workflows-add-… · \$0.00 · 0s · [░░░░░░░░░░] 0%"
expect "L2: <prefix>/jordan-nes-3984-workflows-add-genetic-testing-…"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.00},"session_id":"demo-25","cwd":"'"$LONG_DIR_DEMO"'","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}'

# ─── 26. Worktree path (git detection failed) — ⎇ icon ──────────
clear_caches
WT_PATH_DEMO="$DEMO_DIR/nest/.worktrees/$LONG_NAME_DEMO"
mkdir -p "$WT_PATH_DEMO"
header "26. cwd is inside .worktrees/<name> (no git) — line 2 becomes ⎇ NAME (45-char cap)"
expect "L1: nest · \$0.00 · ..."
expect "L2: ⎇ jordan-nes-3984-workflows-add-genetic-testing…"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.00},"session_id":"demo-26","cwd":"'"$WT_PATH_DEMO"'","context_window":{"context_window_size":200000,"current_usage":{"input_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}'

# ─── 27. Default model hidden (Opus 4.8 1M context) ─────────────
clear_caches
header "27. Opus 4.8 1M context is the default — model name is hidden on line 1"
expect "L1 starts with the project (tmp), NO \"Opus\" shown"
run '{"model":{"display_name":"Claude Opus 4.8 (1M context)"},"cost":{"total_cost_usd":0.62,"total_duration_ms":240000},"session_id":"demo-27","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":6}}'

# ─── 28. Non-default model + effort to its right ────────────────
clear_caches
header "28. Non-default model shows, with reasoning effort to the RIGHT of it"
expect "L1: Opus 4.7 high · tmp · \$0.30 · ..."
run '{"model":{"display_name":"Claude Opus 4.7"},"cost":{"total_cost_usd":0.30,"total_duration_ms":120000},"session_id":"demo-28","cwd":"/tmp","context_window":{"used_percentage":15},"effortLevel":"high"}'

# ─── 29. Default model hidden but effort still shows alone ───────
clear_caches
header "29. Opus 4.8 1M hidden, but effort still rides at the far left when set"
expect "L1: xhigh · tmp · \$0.20 · ... (no \"Opus\")"
run '{"model":{"display_name":"Claude Opus 4.8 (1M context)"},"cost":{"total_cost_usd":0.20,"total_duration_ms":90000},"session_id":"demo-29","cwd":"/tmp","context_window":{"used_percentage":8},"effortLevel":"xhigh"}'

# ─── 30. Rate limit reset countdown ──────────────────────────────
clear_caches
header "30. Rate limit reset countdown (5h critical, resets in ~1h15m)"
expect "5h:85% 1h15m (red); 7d hidden below threshold"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":6.00,"total_duration_ms":3600000},"session_id":"demo-30","cwd":"/tmp","context_window":{"context_window_size":200000,"used_percentage":45},"rate_limits":{"five_hour":{"used_percentage":85.3,"resets_at":'$(($(date +%s) + 4530))'},"seven_day":{"used_percentage":50}}}'

# ─── 31. Open PR — changes requested + CI failure ────────────────
clear_caches
set_pr_cache "$WT1" "jordan/preview-pr" "https://github.com/Nest-Genomics/nest/pull/4567" "OPEN" "false" $'\033[38;5;203m✗\033[0m' "CHANGES_REQUESTED"
header "31. Open PR — changes requested (yellow) + CI failure"
expect "L2: ⎇ #4567 changes ✗ jordan/preview-pr"
run '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":1.40,"total_duration_ms":540000},"session_id":"demo-31","cwd":"'"$WT1"'","context_window":{"context_window_size":200000,"used_percentage":38,"current_usage":{"input_tokens":60000,"cache_creation_input_tokens":4000,"cache_read_input_tokens":12000}}}'

# ─── One-line mode (STATUSLINE_ONE_LINE=1) ───────────────────────
# Same as run() but with one-line mode on and a forced terminal width.
run_one_line() {
  local cols="$1"
  local input="${2//Claude Opus 4.6/Claude Opus 4.8 (1M context)}"
  local output
  output=$(echo "$input" | env -u CLAUDE_EFFORT STATUSLINE_ONE_LINE=1 STATUSLINE_COLS="$cols" bash "$STATUSLINE" 2>/dev/null)
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

# ─── 32. One-line mode, wide terminal ────────────────────────────
clear_caches
header "32. One-line mode (codex style), wide terminal — everything joins with ·"
expect "webapp · \$1.23 ... [bar] 70% (140k) · 🌿 main · +4 -2  — all on ONE line"
run_one_line 300 '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":1.23,"total_duration_ms":300000,"total_lines_added":42,"total_lines_removed":7},"session_id":"demo-32","cwd":"'"$REPO_DIRTY"'","context_window":{"context_window_size":200000,"used_percentage":70,"current_usage":{"input_tokens":80000,"cache_creation_input_tokens":10000,"cache_read_input_tokens":50000}}}'

# ─── 33. One-line mode, narrow terminal → multi-line fallback ────
clear_caches
header "33. One-line mode but terminal too narrow (60 cols) — falls back to multi-line"
expect "Same content as #32 but split across lines (no overflow)"
run_one_line 60 '{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":1.23,"total_duration_ms":300000,"total_lines_added":42,"total_lines_removed":7},"session_id":"demo-33","cwd":"'"$REPO_DIRTY"'","context_window":{"context_window_size":200000,"used_percentage":70,"current_usage":{"input_tokens":80000,"cache_creation_input_tokens":10000,"cache_read_input_tokens":50000}}}'

# ─── 34. Light vs dark terminal background (COLORFGBG) ──────────
clear_caches
BG_JSON='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":0.25,"total_duration_ms":60000},"session_id":"demo-34","cwd":"/tmp","context_window":{"used_percentage":12},"effort":{"level":"high"}}'
header "34. Background detection — same input, dark vs light palette"
expect "dark  (COLORFGBG=15;0): key data near-white (255)"
COLORFGBG="15;0" run "$BG_JSON"
expect "light (COLORFGBG=0;15): key data near-black (235); warnings become amber (130)"
COLORFGBG="0;15" run "$BG_JSON"

# ─── 35. Responsive width fit (anti-wrap / anti double-render) ──
# A line wider than the pane wraps onto an extra terminal row, which reads as a
# double-render in tmux over SSH. As COLUMNS shrinks, line 1 first SHEDS its
# low-value optional segments (cache % → cost-rate → token count → duration),
# then all lines are hard-CLAMPED with … . The [w=NN] prefix is each rendered
# line's visible width — it must never exceed the pane width.
run_cols() {
  local cols="$1"
  local input="${2//Claude Opus 4.6/Claude Opus 4.8 (1M context)}"
  local output vw
  output=$(echo "$input" | env -u CLAUDE_EFFORT STATUSLINE_COLS="$cols" bash "$STATUSLINE" 2>/dev/null)
  while IFS= read -r line; do
    vw=$(printf '%s' "$line" | sed $'s/\033\[[0-9;]*m//g; s/\033]8;;[^\007]*\007//g' | wc -L | tr -d ' ')
    printf '          \033[38;5;245m│ [w=%2s]\033[0m %b\n' "$vw" "$line"
  done <<<"$output"
  echo ""
}

clear_caches
WIDTH_JSON='{"model":{"display_name":"Claude Opus 4.6"},"cost":{"total_cost_usd":4.87,"total_duration_ms":5400000},"session_id":"demo-35","cwd":"/tmp","context_window":{"context_window_size":1000000,"used_percentage":62,"current_usage":{"input_tokens":180000,"cache_creation_input_tokens":20000,"cache_read_input_tokens":420000}},"effort":{"level":"high"}}'
header "35. Same session rendered at shrinking pane widths (no line exceeds w=cols)"
expect "120 cols — full line 1: effort · project · cost (\$/hr) · duration · [bar] % (tokens) ⚡cache"
run_cols 120 "$WIDTH_JSON"
expect "68 cols — sheds cache % (⚡67%)"
run_cols 68 "$WIDTH_JSON"
expect "58 cols — also sheds cost-rate (\$3.25/hr)"
run_cols 58 "$WIDTH_JSON"
expect "48 cols — also sheds token count (620k)"
run_cols 48 "$WIDTH_JSON"
expect "40 cols (phone) — also sheds duration → essentials only"
run_cols 40 "$WIDTH_JSON"
expect "24 cols (tiny) — even essentials overflow → hard clamp with …"
run_cols 24 "$WIDTH_JSON"

printf '\033[38;5;141m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n'
printf '\033[38;5;114m✓ Demo complete — %d variations shown\033[0m\n\n' 32
