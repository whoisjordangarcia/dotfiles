#!/bin/bash

input=$(cat)

# ─── Terminal background detection (COLORFGBG: "fg;bg", bg is last) ───
# Light backgrounds report 7 (silver) or 15 (white); anything else (or an
# unset var, common in Ghostty/tmux) falls back to the dark palette.
_LIGHT_BG=0
case "${COLORFGBG##*;}" in
  7 | 15) _LIGHT_BG=1 ;;
esac

# ─── Colors (soft purple theme) ──────────────────────────────────────
COLOR_ACCENT=$'\033[38;5;141m' # Soft purple — primary accent (reads on both)
if [ "$_LIGHT_BG" = 1 ]; then
  COLOR_WHITE=$'\033[38;5;235m' # Near-black — key data on light bg
  COLOR_WARN=$'\033[38;5;130m'  # Dark amber — warnings on light bg
else
  COLOR_WHITE=$'\033[38;5;255m' # White — key data on dark bg
  COLOR_WARN=$'\033[38;5;221m'  # Yellow — warnings, stale on dark bg
fi
COLOR_DIM=$'\033[38;5;245m' # Medium gray — secondary info (reads on both)
COLOR_ADD=$'\033[38;5;114m' # Green — positive (additions, pass, fresh)
COLOR_DEL=$'\033[38;5;203m' # Red — negative (deletions, fail, critical)
COLOR_RESET=$'\033[0m'

# Aliases (semantic mapping to palette)
COLOR_MODEL="$COLOR_DIM"
COLOR_COST="$COLOR_WHITE"
COLOR_BAR_FULL="$COLOR_ACCENT"
COLOR_BAR_WARNING="$COLOR_WARN"
COLOR_BAR_CRITICAL="$COLOR_DEL"
COLOR_BAR_EMPTY="$COLOR_DIM"
COLOR_PCT="$COLOR_WHITE"
COLOR_PCT_WARNING="$COLOR_WARN"
COLOR_PCT_CRITICAL="$COLOR_DEL"
COLOR_GIT="$COLOR_ACCENT"
COLOR_WORKTREE="$COLOR_DIM"
COLOR_PR_OPEN="$COLOR_ADD"
COLOR_PR_DRAFT="$COLOR_DIM"
COLOR_PR_MERGED=$'\033[38;5;141m'
COLOR_SYNC_AHEAD="$COLOR_WHITE"
COLOR_SYNC_BEHIND="$COLOR_WHITE"
COLOR_CACHE="$COLOR_DIM"
COLOR_CI_PASS="$COLOR_ADD"
COLOR_CI_FAIL="$COLOR_DEL"
COLOR_CI_PENDING="$COLOR_WARN"
COLOR_COMMIT_FRESH="$COLOR_ADD"
COLOR_COMMIT_STALE="$COLOR_WARN"
COLOR_COMMIT_OLD="$COLOR_DEL"
COLOR_BASE="$COLOR_DIM"
COLOR_NODE="$COLOR_ADD"

# ─── Cache config ────────────────────────────────────────────────────
GIT_CACHE_DIR="/tmp/claude-statusline-git-cache"
GIT_CACHE_TTL=10 # seconds
PR_CACHE_DIR="/tmp/claude-statusline-pr-cache"
# PR/CI use stale-while-revalidate: the TTL is a background refresh interval,
# not a render stall — so these can be tighter than they used to be.
PR_CACHE_TTL=120 # 2 minutes
CI_CACHE_TTL=60  # 1 minute — CI changes more often than PR metadata
BASE_CACHE_TTL=600 # 10 minutes — base branch rarely changes
NODE_CACHE_DIR="/tmp/claude-statusline-node-cache"
NODE_CACHE_TTL=30 # 30 seconds — apps can start/stop frequently

# ─── Helper: check if cache file is fresh ────────────────────────────
cache_fresh() {
  local file="$1" ttl="$2"
  [ -f "$file" ] || return 1
  # GNU stat (`-c %Y`) MUST be tried first: on Linux `stat -f %m` is a valid but
  # different option (filesystem mode) that prints a blob to stdout with exit 1,
  # so a BSD-first chain returns garbage and every cache read looks stale. BSD
  # stat rejects `-c` cleanly to stderr, so this order is correct on macOS too.
  local age=$(($(date +%s) - $(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || echo 0)))
  [ "$age" -lt "$ttl" ]
}

# ─── Helper: atomic cache write (temp file + rename) ─────────────────
cache_write() {
  local file="$1" content="$2" tmp
  tmp=$(mktemp "${file}.XXXXXX" 2>/dev/null) || tmp="${file}.$$"
  printf '%s' "$content" >"$tmp" && mv -f "$tmp" "$file"
}

# ─── Helper: stale-while-revalidate cache orchestration ──────────────
# Fresh cache → serve it. Stale cache → serve it anyway, but touch the file
# (claims the refresh slot so concurrent renders don't stack fetches) and
# re-run the fetcher in a detached background job. No cache at all → fetch
# synchronously (first render in this repo only). The fetcher writes the
# cache itself; callers read the cache file after this returns.
swr_refresh() {
  local cache_file="$1" ttl="$2"
  shift 2
  cache_fresh "$cache_file" "$ttl" && return 0
  if [ -f "$cache_file" ]; then
    touch "$cache_file"
    ("$@") </dev/null >/dev/null 2>&1 &
    disown 2>/dev/null || true
  else
    "$@"
  fi
}

# ─── Helper: compact token count (842 / 84k / 1.2M) ──────────────────
format_tokens() {
  local t="$1"
  if [ "$t" -ge 1000000 ]; then
    awk "BEGIN { printf \"%.1fM\", $t / 1000000 }"
  elif [ "$t" -ge 1000 ]; then
    printf '%dk' $((t / 1000))
  else
    printf '%d' "$t"
  fi
}

# ─── Helper: truncate string to max chars with trailing ellipsis ─────
truncate_str() {
  local s="$1" max="$2"
  if [ "${#s}" -gt "$max" ]; then
    printf '%s…' "${s:0:$max}"
  else
    printf '%s' "$s"
  fi
}

# ─── Helper: format reset countdown from epoch ──────────────────────
format_reset() {
  local resets_at="$1" now
  # The docs guarantee epoch seconds; guard anyway so a format change
  # degrades to "no countdown" instead of a bash arithmetic error.
  [[ "$resets_at" =~ ^[0-9]+$ ]] || {
    echo ""
    return
  }
  now=$(date +%s)
  local remaining=$((resets_at - now))
  [ "$remaining" -le 0 ] && echo "now" && return
  if [ "$remaining" -lt 60 ]; then
    echo "<1m"
  elif [ "$remaining" -lt 3600 ]; then
    echo "$((remaining / 60))m"
  else
    local h=$((remaining / 3600))
    local m=$(((remaining % 3600) / 60))
    [ "$m" -gt 0 ] && echo "${h}h${m}m" || echo "${h}h"
  fi
}

# ─── OSC 8 hyperlink support detection ───────────────────────────────
# Terminus iOS and other mobile/non-Ghostty terminals don't support OSC 8;
# sending those sequences causes raw escape text to render alongside the link text.
_OSC8_OK=0
if [ -n "$TMUX" ]; then
  _ct=$(tmux display -p '#{client_termname}' 2>/dev/null || true)
  case "$_ct" in
    *ghostty*|*wezterm*|*iterm*|*kitty*) _OSC8_OK=1 ;;
  esac
else
  case "${TERM_PROGRAM:-}" in
    ghostty|iTerm.app|WezTerm|rio) _OSC8_OK=1 ;;
  esac
fi

# ─── Helper: wrap text in an OSC 8 clickable link ───────────────────
osc_link() {
  local url="$1" text="$2"
  if [ "$_OSC8_OK" = "1" ]; then
    printf '\e]8;;%s\a%s\e]8;;\a' "$url" "$text"
  else
    printf '%s' "$text"
  fi
}

# ─── Helper: fetch CI status into cache (network — runs under SWR) ───
fetch_ci_status() {
  local cwd="$1" branch="$2" cache_file="$3"
  local out="" json failed pending passed
  json=$(cd "$cwd" 2>/dev/null && gh pr checks "$branch" --json name,state,conclusion 2>/dev/null || echo "")
  if [ -n "$json" ] && [ "$json" != "[]" ] && [ "$json" != "null" ]; then
    read -r failed pending passed <<<"$(echo "$json" | jq -r '[
      ([.[] | select(.conclusion == "FAILURE" or .conclusion == "CANCELLED" or .conclusion == "TIMED_OUT")] | length),
      ([.[] | select(.state == "PENDING" or .state == "QUEUED" or .state == "IN_PROGRESS")] | length),
      ([.[] | select(.conclusion == "SUCCESS" or .conclusion == "NEUTRAL" or .conclusion == "SKIPPED")] | length)
    ] | @tsv')"
    if [ "$failed" -gt 0 ] 2>/dev/null; then
      out="${COLOR_CI_FAIL}✗${COLOR_RESET}"
    elif [ "$pending" -gt 0 ] 2>/dev/null; then
      out="${COLOR_CI_PENDING}⏳${COLOR_RESET}"
    elif [ "$passed" -gt 0 ] 2>/dev/null; then
      out="${COLOR_CI_PASS}✓${COLOR_RESET}"
    fi
  fi
  cache_write "$cache_file" "$out"
}

# ─── Helper: render CI status glyph (stale-while-revalidate cached) ──
ci_glyph() {
  local cwd="$1" branch="$2" cache_file="$3" ttl="$4"
  swr_refresh "$cache_file" "$ttl" fetch_ci_status "$cwd" "$branch" "$cache_file"
  cat "$cache_file" 2>/dev/null
}

# ─── Helper: fetch PR metadata into cache ────────────────────────────
# Cache format: url \t state \t isDraft \t reviewDecision
fetch_pr_info() {
  local cwd="$1" branch="$2" cache_file="$3"
  local pr_json url="" state="" draft="" review=""
  pr_json=$(cd "$cwd" 2>/dev/null && gh pr view "$branch" --json url,state,isDraft,reviewDecision 2>/dev/null || echo "")
  if [ -n "$pr_json" ]; then
    IFS=$'\t' read -r url state draft review <<<"$(echo "$pr_json" | jq -r '[(.url // ""), (.state // ""), (.isDraft // false | tostring), (.reviewDecision // "")] | @tsv')"
  fi
  cache_write "$cache_file" "$(printf '%s\t%s\t%s\t%s' "$url" "$state" "$draft" "$review")"
}

# ─── Helper: ANSI color for a PR state/draft combo ───────────────────
pr_state_color() {
  local state="$1" draft="$2"
  if [ "$state" = "MERGED" ]; then
    printf '%s' "$COLOR_PR_MERGED"
  elif [ "$state" = "OPEN" ] && [ "$draft" = "true" ]; then
    printf '%s' "$COLOR_PR_DRAFT"
  elif [ "$state" = "CLOSED" ]; then
    printf '%s' "$COLOR_DIM"
  else
    printf '%s' "$COLOR_PR_OPEN"
  fi
}

# ─── Helper: format seconds as human-readable age with color ─────────
format_commit_age() {
  local secs="$1" color label
  if [ "$secs" -lt 60 ]; then
    label="just now"
    color="$COLOR_COMMIT_FRESH"
  elif [ "$secs" -lt 900 ]; then
    label="$((secs / 60))m ago"
    color="$COLOR_COMMIT_FRESH"
  elif [ "$secs" -lt 3600 ]; then
    label="$((secs / 60))m ago"
    color="$COLOR_COMMIT_STALE"
  elif [ "$secs" -lt 86400 ]; then
    local h=$((secs / 3600))
    local m=$(((secs % 3600) / 60))
    [ "$m" -gt 0 ] && label="${h}h ${m}m ago" || label="${h}h ago"
    color="$COLOR_COMMIT_OLD"
  else
    label="$((secs / 86400))d ago"
    color="$COLOR_COMMIT_OLD"
  fi
  echo "${COLOR_DIM}${label}${COLOR_RESET}"
}

# ─── Single jq call to extract all fields ────────────────────────────
read_data=$(echo "$input" | jq -r '[
	.model.display_name // "Unknown",
	(.cost.total_cost_usd // 0 | tostring),
	(.cost.total_lines_added // 0 | tostring),
	(.cost.total_lines_removed // 0 | tostring),
	.session_id // "",
	(.cwd // .workspace.current_dir // ""),
	(.context_window.used_percentage // 0 | tostring),
	((.context_window.current_usage // null) | if . then ((.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0) | tostring) else "0" end),
	((.context_window.current_usage // null) | if . then (.cache_read_input_tokens // 0 | tostring) else "0" end),
	(.rate_limits.five_hour.used_percentage // -1 | tostring),
	(.rate_limits.seven_day.used_percentage // -1 | tostring),
	(.rate_limits.five_hour.resets_at // "" | tostring),
	(.rate_limits.seven_day.resets_at // "" | tostring),
	(.cost.total_duration_ms // 0 | tostring),
	(.effort.level // .effortLevel // .reasoning_effort // .model.reasoning_effort // .output_style.effortLevel // "")
] | join("\u001f")')

IFS=$'\x1f' read -r model_full cost lines_added lines_removed session_id cwd ctx_pct ctx_current ctx_cache_read rate_5h rate_7d rate_5h_resets rate_7d_resets duration_ms effort_level <<<"$read_data"

# ─── Model name (shorten "Claude Opus 4.6" → "Opus 4.6") ────────────
if [[ "$model_full" =~ Claude\ ([0-9.]+\ )?(.+) ]]; then
  version="${BASH_REMATCH[1]}"
  name="${BASH_REMATCH[2]}"
  model_short="${name}${version:+ ${version% }}"
else
  model_short="$model_full"
fi

# ─── Reasoning effort display ────────────────────────────────────────
# Primary source is .effort.level in the statusline JSON (Claude Code
# ≥2.1.133); $CLAUDE_EFFORT is the documented env-var equivalent fallback.
[ -z "$effort_level" ] && effort_level="${CLAUDE_EFFORT:-}"
effort_display=""
# No leading glyph — the accent-colored level word is the indicator on its own.
[ -n "$effort_level" ] && effort_display="${COLOR_ACCENT}${effort_level}${COLOR_RESET}"

# ─── Session cost ────────────────────────────────────────────────────
cost_display=$(printf '$%.2f' "$cost")

# ─── Session burn rate (from Claude's total_duration_ms) ────────────
# Elapsed duration is no longer displayed on its own; total_duration_ms is
# still used to derive the $/hr burn rate once past a 5-minute warm-up.
duration_seconds=0
cost_rate_display=""

if [ "$duration_ms" -gt 0 ] 2>/dev/null; then
  duration_seconds=$((duration_ms / 1000))

  if [ "$duration_seconds" -gt 300 ] 2>/dev/null; then
    rate=$(awk "BEGIN { printf \"%.2f\", $cost / $duration_seconds * 3600 }")
    cost_rate_display=" ${COLOR_DIM}(${COLOR_COST}\$${rate}/hr${COLOR_DIM})${COLOR_RESET}"
  fi
fi

# ─── Context usage bar ───────────────────────────────────────────────
pct=$(printf '%.0f' "$ctx_pct" 2>/dev/null || echo "0")

# Smooth bar: eighth-block characters give sub-cell resolution, so the bar
# creeps instead of jumping in 10% steps.
bar_len=10
eighths=$((pct * bar_len * 8 / 100))
filled=$((eighths / 8))
part=$((eighths % 8))
partial_blocks=("" "▏" "▎" "▍" "▌" "▋" "▊" "▉")
empty=$((bar_len - filled - (part > 0 ? 1 : 0)))

if [ "$pct" -ge 80 ]; then
  bar_color="$COLOR_BAR_CRITICAL"
  pct_color="$COLOR_PCT_CRITICAL"
  warn=" ⚠️"
elif [ "$pct" -ge 50 ]; then
  bar_color="$COLOR_BAR_WARNING"
  pct_color="$COLOR_PCT_WARNING"
  warn=""
else
  bar_color="$COLOR_BAR_FULL"
  pct_color="$COLOR_PCT"
  warn=""
fi

filled_bar=""
empty_bar=""
for ((i = 0; i < filled; i++)); do filled_bar+="█"; done
filled_bar+="${partial_blocks[$part]}"
for ((i = 0; i < empty; i++)); do empty_bar+="░"; done

# Absolute token count next to the % — 42% means different things in a
# 200k window vs a 1M one.
tokens_display=""
if [ "$ctx_current" -gt 0 ] 2>/dev/null; then
  tokens_display=" ${COLOR_DIM}($(format_tokens "$ctx_current"))${COLOR_RESET}"
fi
# tokens_display and warn are kept OUT of context_bar so line-1 assembly can
# drop the token count independently on a narrow pane (build_line1 below).
context_bar="${COLOR_DIM}[${COLOR_RESET}${bar_color}${filled_bar}${COLOR_BAR_EMPTY}${empty_bar}${COLOR_DIM}]${COLOR_RESET} ${pct_color}${pct}%${COLOR_RESET}"

# ─── Cache hit rate ──────────────────────────────────────────────────
cache_display=""
if [ "$ctx_current" -gt 0 ] 2>/dev/null && [ "$ctx_cache_read" -gt 0 ] 2>/dev/null; then
  cache_pct=$((ctx_cache_read * 100 / ctx_current))
  if [ "$cache_pct" -lt 80 ]; then
    cache_display=" ${COLOR_CACHE}⚡${cache_pct}%${COLOR_RESET}"
  fi
fi

# ─── Git info (cached for performance) ───────────────────────────────
branch=""
is_worktree=false
wt_name=""
sync_display=""
dirty_display=""
git_lines_display=""
commit_age_display=""
base_branch_display=""
pr_number=""
pr_url=""
pr_state=""
pr_draft=""

if [ -n "$cwd" ] && [ -d "$cwd" ] && { [ -d "$cwd/.git" ] || [ -f "$cwd/.git" ]; }; then
  mkdir -p "$GIT_CACHE_DIR"
  cache_key=$(printf '%s' "$cwd" | md5 -q 2>/dev/null || printf '%s' "$cwd" | md5sum | cut -d' ' -f1)

  # Branch name (cheap — always fetch live)
  branch=$(cd "$cwd" 2>/dev/null && git -c core.useBuiltinFSMonitor=false branch --show-current 2>/dev/null)

  # Git dirs (needed for project name resolution + worktree fallback)
  # Both must be absolute: --git-dir alone returns a relative ".git" at a repo
  # root, which never equals the absolute --git-common-dir and would misflag
  # every normal repo as a worktree named ".git".
  git_dir=$(cd "$cwd" 2>/dev/null && git rev-parse --path-format=absolute --git-dir 2>/dev/null)
  git_common=$(cd "$cwd" 2>/dev/null && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)

  # Worktree detection fallback (if Claude didn't provide it)
  if [ "$is_worktree" = false ]; then
    if [ -n "$git_dir" ] && [ -n "$git_common" ] && [ "$git_dir" != "$git_common" ]; then
      is_worktree=true
      if [[ "$cwd" =~ (/\.claude/worktrees/|/\.worktrees/|/\.worktree/)([^/]+)(/|$) ]]; then
        wt_name="${BASH_REMATCH[2]}"
      else
        wt_name="${git_dir##*/}"
      fi
    fi
  fi

  # Sync status + dirty status (cached — these are expensive in monorepos)
  sync_cache="$GIT_CACHE_DIR/${cache_key}_sync"
  dirty_cache="$GIT_CACHE_DIR/${cache_key}_dirty"

  if cache_fresh "$sync_cache" "$GIT_CACHE_TTL"; then
    sync_display=$(cat "$sync_cache")
  else
    upstream_info=$(cd "$cwd" 2>/dev/null && git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
    sync_display=""
    if [ -n "$upstream_info" ]; then
      ahead=$(echo "$upstream_info" | awk '{print $1}')
      behind=$(echo "$upstream_info" | awk '{print $2}')
      [ "$ahead" -gt 0 ] 2>/dev/null && sync_display+="${COLOR_SYNC_AHEAD}↑${ahead}${COLOR_RESET}"
      [ "$behind" -gt 0 ] 2>/dev/null && {
        [ -n "$sync_display" ] && sync_display+=" "
        sync_display+="${COLOR_SYNC_BEHIND}↓${behind}${COLOR_RESET}"
      }
    fi
    cache_write "$sync_cache" "$sync_display"
  fi

  if cache_fresh "$dirty_cache" "$GIT_CACHE_TTL"; then
    dirty_display=$(cat "$dirty_cache")
  else
    dirty_display=""
    git_status=$(cd "$cwd" 2>/dev/null && git status --porcelain 2>/dev/null)
    if [ -n "$git_status" ]; then
      staged=$(grep -c '^[MADRC]' <<<"$git_status" 2>/dev/null) || staged=0
      unstaged=$(grep -c '^.[MD]' <<<"$git_status" 2>/dev/null) || unstaged=0
      untracked=$(grep -c '^??' <<<"$git_status" 2>/dev/null) || untracked=0
      [ "$staged" -gt 0 ] && dirty_display+="${COLOR_ADD}●${staged}${COLOR_RESET}"
      [ "$unstaged" -gt 0 ] && {
        [ -n "$dirty_display" ] && dirty_display+=" "
        dirty_display+="${COLOR_SYNC_AHEAD}◦${unstaged}${COLOR_RESET}"
      }
      [ "$untracked" -gt 0 ] && {
        [ -n "$dirty_display" ] && dirty_display+=" "
        dirty_display+="${COLOR_CACHE}+${untracked}${COLOR_RESET}"
      }
    fi
    cache_write "$dirty_cache" "$dirty_display"
  fi

  # Uncommitted line changes vs HEAD (cached) — "+added -deleted" of tracked
  # working-tree edits, staged or not. Collapses to nothing once everything is
  # committed, so it doubles as a "you have uncommitted work" signal. Untracked
  # files aren't counted (git diff ignores them); their count is in dirty_display.
  gitlines_cache="$GIT_CACHE_DIR/${cache_key}_gitlines"
  if cache_fresh "$gitlines_cache" "$GIT_CACHE_TTL"; then
    git_lines_display=$(cat "$gitlines_cache")
  else
    git_lines_display=""
    # ` N files changed, A insertions(+), D deletions(-)` — either count may be absent.
    shortstat=$(cd "$cwd" 2>/dev/null && git diff --shortstat HEAD 2>/dev/null)
    if [ -n "$shortstat" ]; then
      g_added=$(grep -oE '[0-9]+ insertion' <<<"$shortstat" | grep -oE '^[0-9]+') || g_added=0
      g_removed=$(grep -oE '[0-9]+ deletion' <<<"$shortstat" | grep -oE '^[0-9]+') || g_removed=0
      [ -n "$g_added" ] || g_added=0
      [ -n "$g_removed" ] || g_removed=0
      [ "$g_added" -gt 0 ] 2>/dev/null && git_lines_display+="${COLOR_ADD}+${g_added}${COLOR_RESET}"
      [ "$g_removed" -gt 0 ] 2>/dev/null && {
        [ -n "$git_lines_display" ] && git_lines_display+=" "
        git_lines_display+="${COLOR_DEL}-${g_removed}${COLOR_RESET}"
      }
    fi
    cache_write "$gitlines_cache" "$git_lines_display"
  fi

  # Last commit age (cached with git cache TTL)
  commit_cache="$GIT_CACHE_DIR/${cache_key}_commit"
  if cache_fresh "$commit_cache" "$GIT_CACHE_TTL"; then
    commit_age_display=$(cat "$commit_cache")
  else
    commit_epoch=$(cd "$cwd" 2>/dev/null && git log -1 --format=%ct 2>/dev/null)
    commit_age_display=""
    if [ -n "$commit_epoch" ] && [ "$commit_epoch" -gt 0 ] 2>/dev/null; then
      age_secs=$(($(date +%s) - commit_epoch))
      if [ "$age_secs" -lt 18000 ]; then
        commit_age_display=$(format_commit_age "$age_secs")
      fi
    fi
    cache_write "$commit_cache" "$commit_age_display"
  fi

  # Base branch detection (heavily cached — rarely changes)
  base_cache="$GIT_CACHE_DIR/${cache_key}_base"
  if cache_fresh "$base_cache" "$BASE_CACHE_TTL"; then
    base_branch_display=$(cat "$base_cache")
  else
    base_branch_display=""
    if [ -n "$branch" ]; then
      # Nearest-base heuristic: among candidate bases, pick the one whose
      # merge-base is the fewest commits behind HEAD — i.e. the branch this
      # one was most plausibly cut from. Release branches are listed first
      # (Nest convention) so they win exact-distance ties.
      # Filter to only semver release branches (e.g. release/2.15.0), skip suffixed ones like release/2.15.0-stg-sync
      base_ref=""
      best_dist=-1
      release_refs=$(cd "$cwd" 2>/dev/null && git branch -r --list 'origin/release/*' --sort=-version:refname 2>/dev/null | grep -E '/release/[0-9]+\.[0-9]+\.[0-9]+$' | head -5 | sed 's/^ *//')
      for ref in $release_refs origin/stg origin/main origin/master; do
        mb=$(cd "$cwd" 2>/dev/null && git merge-base "$ref" HEAD 2>/dev/null)
        [ -n "$mb" ] || continue
        dist=$(cd "$cwd" 2>/dev/null && git rev-list --count "$mb..HEAD" 2>/dev/null)
        [ -n "$dist" ] || continue
        if [ "$best_dist" -lt 0 ] || [ "$dist" -lt "$best_dist" ]; then
          best_dist="$dist"
          base_ref="${ref#origin/}"
        fi
      done
      [ -n "$base_ref" ] && [ "$base_ref" != "$branch" ] && base_branch_display="${COLOR_DIM}← ${COLOR_BASE}${base_ref}${COLOR_RESET}"
    fi
    cache_write "$base_cache" "$base_branch_display"
  fi
fi

# ─── Path-based worktree detection (runs even when git detection fails) ─
wt_main_repo=""
if [ "$is_worktree" = false ] && [ -n "$cwd" ]; then
  if [[ "$cwd" =~ ^(.*)(/\.claude/worktrees/|/\.worktrees/|/\.worktree/)([^/]+) ]]; then
    is_worktree=true
    wt_main_repo="${BASH_REMATCH[1]}"
    wt_name="${BASH_REMATCH[3]}"
  fi
fi

# ─── PR detection + CI status (stale-while-revalidate cached) ────────
ci_display=""
pr_badge=""
if [ -n "$branch" ] && [ -n "$cwd" ]; then
  mkdir -p "$PR_CACHE_DIR"
  pr_cache_key=$(printf '%s:%s' "$cwd" "$branch" | md5 -q 2>/dev/null || printf '%s:%s' "$cwd" "$branch" | md5sum | cut -d' ' -f1)
  pr_cache_file="$PR_CACHE_DIR/$pr_cache_key"

  swr_refresh "$pr_cache_file" "$PR_CACHE_TTL" fetch_pr_info "$cwd" "$branch" "$pr_cache_file"
  IFS=$'\t' read -r pr_url pr_state pr_draft pr_review <<<"$(cat "$pr_cache_file" 2>/dev/null)"

  if [ -n "$pr_url" ]; then
    pr_number="${pr_url##*/}"
    pr_suffix=""
    case "$pr_state" in
      MERGED) pr_suffix=" merged" ;;
      CLOSED) pr_suffix=" closed" ;;
      OPEN) [ "$pr_draft" = "true" ] && pr_suffix=" draft" ;;
    esac
    # Review decision only matters for open, non-draft PRs
    review_display=""
    if [ "$pr_state" = "OPEN" ] && [ "$pr_draft" != "true" ]; then
      case "$pr_review" in
        APPROVED) review_display="${COLOR_ADD}approved${COLOR_RESET}" ;;
        CHANGES_REQUESTED) review_display="${COLOR_WARN}changes${COLOR_RESET}" ;;
      esac
    fi
    # CI only matters while the PR is open
    [ "$pr_state" = "OPEN" ] && ci_display=$(ci_glyph "$cwd" "$branch" "$PR_CACHE_DIR/${pr_cache_key}_ci" "$CI_CACHE_TTL")
    pr_badge="$(pr_state_color "$pr_state" "$pr_draft")$(osc_link "$pr_url" "#${pr_number}")${pr_suffix}${COLOR_RESET}"
    [ -n "$review_display" ] && pr_badge+=" ${review_display}"
    [ -n "$ci_display" ] && pr_badge+=" ${ci_display}"
  fi
fi

# ─── Uncommitted line changes (git working tree vs HEAD) ─────────────
# Was the session edit counter (.cost.total_lines_*); now mirrors the git diff
# so it answers "do I have uncommitted work?" and resets on commit. Computed
# (and colorized) in the git block above; empty outside a git repo.
lines_display="$git_lines_display"

# ─── Assemble output ─────────────────────────────────────────────────
sep=" ${COLOR_DIM}·${COLOR_RESET} "

# Project name: main repo name for worktrees, else cwd basename
project_name=""
if [ "$is_worktree" = true ] && [ -n "$git_common" ]; then
  main_repo="${git_common%/.git}"
  [ -n "$main_repo" ] && project_name="${main_repo##*/}"
elif [ "$is_worktree" = true ] && [ -n "$wt_main_repo" ]; then
  project_name="${wt_main_repo##*/}"
elif [ -n "$cwd" ]; then
  project_name="${cwd##*/}"
fi

# Truncate overlong project names (worktree folders can run 60+ chars)
project_name=$(truncate_str "$project_name" 30)

# Worktree/PR indicator (rendered on line 2)
wt_pr_display=""
if [ -n "$branch" ]; then
  if [ "$is_worktree" = true ] && [ -n "$wt_name" ]; then
    if [ -n "$pr_badge" ]; then
      wt_pr_display="$(pr_state_color "$pr_state" "$pr_draft")⎇${COLOR_RESET} ${pr_badge}"
    else
      # Skip ⎇ label when worktree name matches the branch (ignoring / and - and case)
      norm_branch=$(printf '%s' "$branch" | tr -d '/-' | tr '[:upper:]' '[:lower:]')
      norm_wt=$(printf '%s' "$wt_name" | tr -d '/-' | tr '[:upper:]' '[:lower:]')
      if [ "$norm_branch" != "$norm_wt" ]; then
        wt_pr_display="${COLOR_WORKTREE}⎇ $(truncate_str "$wt_name" 45)${COLOR_RESET}"
      fi
    fi
  elif [ -n "$pr_badge" ]; then
    wt_pr_display="$pr_badge"
  fi
fi

# Line 1: model + effort · project · cost · session vitals
# Model segment (far left of line 1). Hide the default model (Opus 4.8 1M —
# showing it is noise); show anything else. Override per-machine with
# STATUSLINE_HIDE_MODEL_REGEX instead of editing this file.
# Reasoning effort rides to the right of the model — or stands alone when the model is hidden.
hide_model_regex="${STATUSLINE_HIDE_MODEL_REGEX:-Opus 4\.8.*1M}"
model_segment=""
if [[ ! "$model_short" =~ $hide_model_regex ]]; then
  model_segment="${COLOR_MODEL}${model_short}${COLOR_RESET}"
fi
if [ -n "$effort_display" ]; then
  [ -n "$model_segment" ] && model_segment+=" "
  model_segment+="${effort_display}"
fi

# Assemble line 1 with a selectable set of optional segments. On a narrow pane
# the print section rebuilds with fewer of them (cache % → cost-rate → token
# count) so the line shrinks to fit instead of wrapping. The essentials —
# model/effort · project · cost · context bar % — always render.
# Args (1/0): include cost-rate, token count, cache %.
build_line1() {
  local inc_rate="$1" inc_tok="$2" inc_cache="$3" l=""
  [ -n "$project_name" ] && l+="${COLOR_WHITE}${project_name}${COLOR_RESET}"
  [ -n "$l" ] && l+="${sep}"
  l+="${COLOR_COST}${cost_display}${COLOR_RESET}"
  [ -n "$model_segment" ] && l="${model_segment}${sep}${l}"
  [ "$inc_rate" = 1 ] && [ -n "$cost_rate_display" ] && l+="${cost_rate_display}"
  l+="${sep}${context_bar}"
  [ "$inc_tok" = 1 ] && l+="${tokens_display}"
  l+="${warn}"
  [ "$inc_cache" = 1 ] && l+="${cache_display}"
  printf '%s' "$l"
}
line1=$(build_line1 1 1 1)
# Rate limits: hide when low; show 5h at ≥70% and 7d at ≥80%
rate_display=""
rate_5h_int=0
rate_7d_int=0
[ "$rate_5h" != "-1" ] 2>/dev/null && rate_5h_int=$(printf '%.0f' "$rate_5h" 2>/dev/null || echo "0")
[ "$rate_7d" != "-1" ] 2>/dev/null && rate_7d_int=$(printf '%.0f' "$rate_7d" 2>/dev/null || echo "0")

if [ "$rate_5h_int" -ge 70 ] 2>/dev/null; then
  reset_label=""
  [ -n "$rate_5h_resets" ] && [ "$rate_5h_resets" != "null" ] && reset_label=" $(format_reset "$rate_5h_resets")"
  if [ "$rate_5h_int" -ge 80 ] 2>/dev/null; then
    rate_display+="${COLOR_DEL}5h:${rate_5h_int}%${reset_label}${COLOR_RESET}"
  else
    rate_display+="${COLOR_WARN}5h:${rate_5h_int}%${reset_label}${COLOR_RESET}"
  fi
fi

if [ "$rate_7d_int" -ge 80 ] 2>/dev/null; then
  reset_label=""
  [ -n "$rate_7d_resets" ] && [ "$rate_7d_resets" != "null" ] && reset_label=" $(format_reset "$rate_7d_resets")"
  [ -n "$rate_display" ] && rate_display+=" "
  rate_display+="${COLOR_DEL}7d:${rate_7d_int}%${reset_label}${COLOR_RESET}"
fi

# Line 2: worktree · branch · sync · dirty · lines · commit age
line2=""

if [ -n "$branch" ]; then
  if [ "$is_worktree" = true ]; then
    # Worktree: show ⎇ indicator + branch + sync + dirty
    [ -n "$wt_pr_display" ] && line2+="${wt_pr_display}"
    if [ -n "$branch" ]; then
      [ -n "$line2" ] && line2+=" "
      line2+="${COLOR_GIT}$(truncate_str "$branch" 45)${COLOR_RESET}"
    fi
    [ -n "$base_branch_display" ] && line2+=" ${base_branch_display}"
    [ -n "$sync_display" ] && {
      [ -n "$line2" ] && line2+="${sep}"
      line2+="${sync_display}"
    }
    [ -n "$dirty_display" ] && {
      [ -n "$line2" ] && line2+="${sep}"
      line2+="${dirty_display}"
    }
  else
    line2+="${COLOR_GIT}$(truncate_str "$branch" 45)${COLOR_RESET}"
    [ -n "$wt_pr_display" ] && line2+=" ${wt_pr_display}"
    [ -n "$base_branch_display" ] && line2+=" ${base_branch_display}"
    [ -n "$sync_display" ] && line2+="${sep}${sync_display}"
    [ -n "$dirty_display" ] && line2+="${sep}${dirty_display}"
  fi
fi

if [ -z "$line2" ] && [ "$is_worktree" = true ] && [ -n "$wt_name" ]; then
  # Worktree detected but no branch (git read failed) — show ⎇ NAME instead of the raw path
  line2="${COLOR_WORKTREE}⎇ $(truncate_str "$wt_name" 45)${COLOR_RESET}"
elif [ -z "$line2" ] && [ -n "$cwd" ] && [ "$is_worktree" != true ]; then
  # No git (and not a worktree) — show full path with ~ shorthand
  line2="${COLOR_WHITE}$(truncate_str "${cwd/#$HOME/~}" 50)${COLOR_RESET}"
fi

# Lines changed on line 2
[ -n "$lines_display" ] && {
  [ -n "$line2" ] && line2+="${sep}"
  line2+="${lines_display}"
}

# Commit age on line 2
[ -n "$commit_age_display" ] && {
  [ -n "$line2" ] && line2+="${sep}"
  line2+="${commit_age_display}"
}

# ─── Node app detection (line 3) ───────────────────────────────────
# Nest frontend dev servers run https on custom hostnames (mkcert certs,
# see each app's dev.server.js); everything else falls back to localhost.
node_app_url() {
  local name="$1" port="$2"
  case "$name" in
    yoda) printf 'https://dev.yoda.nestgenomics.com:%s' "$port" ;;
    patient-navigator) printf 'https://dev.app.nestgenomics.com:%s' "$port" ;;
    provider-portal) printf 'https://dev.portal.nestgenomics.com:%s' "$port" ;;
    *) printf 'http://localhost:%s' "$port" ;;
  esac
}

fetch_node_apps() {
  local cwd="$1" cache_file="$2"
  local listening app_entries="" parts=""
  local l_pid l_addr l_port proc_args proc_cwd in_scope app_name combined
  listening=$(lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | awk '$1 == "node" && $2 ~ /^[0-9]+$/ {print $2, $9}' | sort -u)
  if [ -n "$listening" ]; then
    while read -r l_pid l_addr; do
      l_port=$(echo "$l_addr" | grep -oE '[0-9]+$')
      [ -z "$l_port" ] && continue
      proc_args=$(ps -p "$l_pid" -o args= 2>/dev/null || true)
      proc_cwd=$(lsof -p "$l_pid" -a -d cwd -Fn 2>/dev/null | grep '^n/' | head -1 | cut -c2-)
      # Only show apps belonging to the current project directory
      in_scope=false
      if echo "$proc_args" | grep -qF "$cwd"; then
        in_scope=true
      elif [ -n "$proc_cwd" ] && echo "$proc_cwd" | grep -qF "$cwd"; then
        in_scope=true
      fi
      [ "$in_scope" = false ] && continue
      app_name=""
      combined="$proc_args $proc_cwd"
      if echo "$combined" | grep -qE 'apps/backend/[^/]+'; then
        # Match by the service dir alone — `node dist/main.js` run from the
        # app's cwd puts "apps/backend/<name>" in proc_cwd but not contiguous
        # with the "/dist" in proc_args, so requiring "/dist" here missed it
        # and fell through to the bare worktree-name fallback.
        app_name=$(echo "$combined" | sed -n 's|.*apps/backend/\([^/ ]*\).*|\1|p' | head -1)
      elif echo "$combined" | grep -qE 'apps/frontend/[^/]+'; then
        app_name=$(echo "$combined" | sed -n 's|.*apps/frontend/\([^/]*\).*|\1|p' | head -1)
      elif echo "$proc_args" | grep -qE 'nx\.js run [^:]+:'; then
        app_name=$(echo "$proc_args" | sed -n 's|.*nx\.js run \([^:]*\):.*|\1|p')
      fi
      # Fallback for non-monorepo projects (plain Next.js, Vite, etc.): name the
      # app after the project directory so the running dev server still shows
      # with a clickable http://localhost:<port> link.
      [ -z "$app_name" ] && app_name="${cwd##*/}"
      [ -n "$app_name" ] && app_entries="${app_entries}${app_name}:${l_port}\n"
    done <<<"$listening"
  fi
  if [ -n "$app_entries" ]; then
    parts=$(printf '%b' "$app_entries" | sort -u -t: -k1,1 | tr '\n' ' ' | sed 's/ $//')
  fi
  # Cache stores plain "name:port" entries — color + clickable links are
  # rendered at display time so the cache stays format-agnostic.
  cache_write "$cache_file" "$parts"
}

node_display=""
if [ -n "$cwd" ]; then
  mkdir -p "$NODE_CACHE_DIR"
  node_cache_key=$(printf '%s' "$cwd" | md5 -q 2>/dev/null || printf '%s' "$cwd" | md5sum | cut -d' ' -f1)
  node_cache_file="$NODE_CACHE_DIR/${node_cache_key}_node"
  # Skip the lsof scan entirely unless this looks like a Node project
  # (or a previous scan already left a cache to serve/refresh).
  if [ -f "$cwd/package.json" ] || [ -f "$node_cache_file" ]; then
    swr_refresh "$node_cache_file" "$NODE_CACHE_TTL" fetch_node_apps "$cwd" "$node_cache_file"
    node_parts=$(cat "$node_cache_file" 2>/dev/null)
    if [ -n "$node_parts" ]; then
      # Wrap each "name:port" in an OSC 8 link so the port opens the app
      node_linked=""
      for node_entry in $node_parts; do
        node_port="${node_entry##*:}"
        if [[ "$node_port" =~ ^[0-9]+$ ]]; then
          node_linked+="${node_linked:+ }$(osc_link "$(node_app_url "${node_entry%:*}" "$node_port")" "$node_entry")"
        else
          node_linked+="${node_linked:+ }${node_entry}"
        fi
      done
      node_display="${COLOR_NODE}${node_linked}${COLOR_RESET}"
    fi
  fi
fi

# Build line 3: rate warnings (already threshold-filtered) · running apps
line3=""
[ -n "$rate_display" ] && line3+="${rate_display}"
if [ -n "$node_display" ]; then
  [ -n "$line3" ] && line3+="${sep}"
  line3+="${node_display}"
fi

# ─── Helper: visible width of a line (ANSI colors + OSC 8 stripped) ─
# Uses `wc -L` (wcwidth-based display columns), not ${#s} (codepoints): wide
# glyphs like ⚡ and ⚠️ occupy 2 columns but 1–2 codepoints, and the terminal
# wraps on columns — so codepoint counts undercount and let a line overflow.
visible_width() {
  printf '%s' "$1" | sed $'s/\033\[[0-9;]*m//g; s/\033]8;;[^\007]*\007//g' | wc -L | tr -d ' '
}

# ─── Helper: clamp a colored/linked line to `max` visible columns ────
# A line wider than the pane wraps onto an extra terminal row that Claude
# Code didn't reserve — the tmux-over-SSH "double render". This hard-limits
# any line so that can't happen. ANSI SGR (\e[..m) and OSC 8 (\e]8;;..\a)
# sequences are copied but don't count toward width; a cut made inside a
# hyperlink is closed so the link state can't bleed into later output.
# Appends … (which occupies the reserved final column) when it truncates.
fit_line() {
  local s="$1" max="$2"
  [ "$max" -gt 0 ] 2>/dev/null || { printf '%s' "$s"; return; }
  [ "$(visible_width "$s")" -le "$max" ] && { printf '%s' "$s"; return; }
  local out="" vis=0 i=0 n=${#s} c nxt j lim=$((max - 1)) osc_open=0
  while [ "$i" -lt "$n" ]; do
    c=${s:i:1}
    if [ "$c" = $'\033' ]; then
      nxt=${s:i+1:1}
      if [ "$nxt" = "]" ]; then
        # OSC 8: copy through the BEL terminator
        j=$((i + 1))
        while [ "$j" -lt "$n" ] && [ "${s:j:1}" != $'\007' ]; do j=$((j + 1)); done
        out+=${s:i:j-i+1}
        if [ "${s:i:6}" = $'\033]8;;\007' ]; then osc_open=0; else osc_open=1; fi
        i=$((j + 1))
        continue
      fi
      # CSI/SGR: copy through the letter terminator
      j=$((i + 1))
      while [ "$j" -lt "$n" ]; do
        case "${s:j:1}" in [A-Za-z]) break ;; esac
        j=$((j + 1))
      done
      out+=${s:i:j-i+1}
      i=$((j + 1))
      continue
    fi
    [ "$vis" -ge "$lim" ] && break
    out+=$c
    vis=$((vis + 1))
    i=$((i + 1))
  done
  [ "$osc_open" = 1 ] && out+=$'\033]8;;\007'
  printf '%s%s…' "$out" $'\033[0m'
}

# ─── Helper: terminal width (statusline stdout is not a tty) ────────
# Order: explicit override → inherited COLUMNS → controlling tty.
# Empty/0 means unknown — caller decides the fallback.
term_width() {
  if [ -n "${STATUSLINE_COLS:-}" ]; then
    printf '%s' "$STATUSLINE_COLS"
  elif [ -n "${COLUMNS:-}" ] && [ "$COLUMNS" -gt 0 ] 2>/dev/null; then
    printf '%s' "$COLUMNS"
  else
    # 2>/dev/null must come first: redirections apply left-to-right, and a
    # missing /dev/tty errors during redirection setup, not from stty itself.
    stty size 2>/dev/null </dev/tty | awk '{print $2}'
  fi
}

# Print (printf %b for reliable OSC 8 link rendering)
# STATUSLINE_ONE_LINE=1 joins everything onto a single codex-style line —
# but only when it fits the terminal; too wide falls back to multi-line
# (wrapped/clipped one-liners are worse than two short lines).
# Terminal width from COLUMNS (Claude Code sets it; the statusline stdout is
# not a tty so tput/stty can't read it). Empty/0 → unknown, keep everything.
cols=$(term_width)

use_one_line=false
if [ -n "${STATUSLINE_ONE_LINE:-}" ]; then
  one_line="$line1"
  [ -n "$line2" ] && one_line+="${sep}${line2}"
  [ -n "$line3" ] && one_line+="${sep}${line3}"
  use_one_line=true
  if [ -f /tmp/statusline-debug ]; then
    printf '%s cols=%s COLUMNS=%s stty=%s linewidth=%s\n' \
      "$(date +%T)" "$cols" "${COLUMNS:-unset}" \
      "$(stty size 2>/dev/null </dev/tty | awk '{print $2}')" \
      "$(visible_width "$one_line")" >>/tmp/statusline-debug.log
  fi
  if [ "$cols" -gt 0 ] 2>/dev/null && [ "$(visible_width "$one_line")" -gt "$cols" ]; then
    use_one_line=false
  fi
fi

if [ "$use_one_line" = true ]; then
  printf '%b\n' "$one_line"
else
  # Fit every line to the pane so none wrap — a wrapped line takes an extra
  # terminal row the renderer didn't reserve, which reads as a double-render
  # in tmux over SSH. Line 1 first sheds its low-value optional segments
  # (cache % → cost-rate → token count); then all lines are hard-clamped as a
  # final guarantee. cols unknown → leave everything as-is.
  if [ "$cols" -gt 0 ] 2>/dev/null; then
    for combo in "1 1 1" "1 1 0" "0 1 0" "0 0 0"; do
      line1=$(build_line1 $combo)
      [ "$(visible_width "$line1")" -le "$cols" ] && break
    done
    line1=$(fit_line "$line1" "$cols")
    [ -n "$line2" ] && line2=$(fit_line "$line2" "$cols")
    [ -n "$line3" ] && line3=$(fit_line "$line3" "$cols")
  fi
  printf '%b\n' "$line1"
  [ -n "$line2" ] && printf '%b\n' "$line2"
  [ -n "$line3" ] && printf '%b\n' "$line3"
fi

exit 0
