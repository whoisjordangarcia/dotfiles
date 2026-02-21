#!/bin/bash

input=$(cat)

# ─── Colors (elegant, subtle palette) ────────────────────────────────
COLOR_MODEL=$'\033[38;5;141m'          # Soft purple
COLOR_COST=$'\033[38;5;114m'           # Soft green
COLOR_BAR_FULL=$'\033[38;5;110m'       # Blue-gray
COLOR_BAR_WARNING=$'\033[38;5;221m'    # Yellow (50%+)
COLOR_BAR_CRITICAL=$'\033[38;5;196m'   # Red (80%+)
COLOR_BAR_EMPTY=$'\033[38;5;240m'      # Dark gray
COLOR_PCT=$'\033[38;5;147m'            # Light blue
COLOR_PCT_WARNING=$'\033[38;5;221m'    # Yellow
COLOR_PCT_CRITICAL=$'\033[38;5;196m'   # Red
COLOR_DUR=$'\033[38;5;183m'            # Soft pink
COLOR_GIT=$'\033[38;5;173m'            # Soft coral
COLOR_DIM=$'\033[38;5;238m'            # Subtle gray (separators, secondary)
COLOR_WORKTREE=$'\033[38;5;114m'       # Soft green
COLOR_PR=$'\033[38;5;75m'              # Light blue
COLOR_PR_MERGED=$'\033[38;5;139m'      # Muted purple for merged PRs
COLOR_SYNC_AHEAD=$'\033[38;5;221m'     # Yellow
COLOR_SYNC_BEHIND=$'\033[38;5;209m'    # Orange
COLOR_ADD=$'\033[38;5;114m'            # Green
COLOR_DEL=$'\033[38;5;203m'            # Red
COLOR_CACHE=$'\033[38;5;117m'          # Soft cyan for cache hit rate
COLOR_CI_PASS=$'\033[38;5;114m'        # Green
COLOR_CI_FAIL=$'\033[38;5;196m'        # Red
COLOR_CI_PENDING=$'\033[38;5;221m'     # Yellow
COLOR_COMMIT_FRESH=$'\033[38;5;114m'   # Green — committed recently
COLOR_COMMIT_STALE=$'\033[38;5;221m'   # Yellow — getting stale
COLOR_COMMIT_OLD=$'\033[38;5;203m'     # Red — should commit soon
COLOR_BASE=$'\033[38;5;139m'           # Muted purple for base branch
COLOR_RESET=$'\033[0m'

# ─── Cache config ────────────────────────────────────────────────────
GIT_CACHE_DIR="/tmp/claude-statusline-git-cache"
GIT_CACHE_TTL=10    # seconds
PR_CACHE_DIR="/tmp/claude-statusline-pr-cache"
PR_CACHE_TTL=300    # 5 minutes
CI_CACHE_TTL=120    # 2 minutes — CI changes more often than PR metadata
BASE_CACHE_TTL=600  # 10 minutes — base branch rarely changes

# ─── Helper: check if cache file is fresh ────────────────────────────
cache_fresh() {
	local file="$1" ttl="$2"
	[ -f "$file" ] || return 1
	local age=$(( $(date +%s) - $(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo 0) ))
	[ "$age" -lt "$ttl" ]
}

# ─── Helper: format seconds as human-readable age with color ─────────
format_commit_age() {
	local secs="$1" color label
	if [ "$secs" -lt 60 ]; then
		label="just now"; color="$COLOR_COMMIT_FRESH"
	elif [ "$secs" -lt 900 ]; then
		label="$(( secs / 60 ))m ago"; color="$COLOR_COMMIT_FRESH"
	elif [ "$secs" -lt 3600 ]; then
		label="$(( secs / 60 ))m ago"; color="$COLOR_COMMIT_STALE"
	elif [ "$secs" -lt 86400 ]; then
		local h=$(( secs / 3600 ))
		local m=$(( (secs % 3600) / 60 ))
		[ "$m" -gt 0 ] && label="${h}h${m}m ago" || label="${h}h ago"
		color="$COLOR_COMMIT_OLD"
	else
		label="$(( secs / 86400 ))d ago"; color="$COLOR_COMMIT_OLD"
	fi
	echo "${color}${label}${COLOR_RESET}"
}

# ─── Single jq call to extract all fields ────────────────────────────
read_data=$(echo "$input" | jq -r '[
	.model.display_name // "Unknown",
	(.cost.total_cost_usd // 0 | tostring),
	(.cost.total_lines_added // 0 | tostring),
	(.cost.total_lines_removed // 0 | tostring),
	.session_id // "",
	(.cwd // .workspace.current_dir // ""),
	(.context_window.context_window_size // 0 | tostring),
	((.context_window.current_usage // null) | if . then (.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens | tostring) else "0" end),
	((.context_window.current_usage // null) | if . then (.cache_read_input_tokens // 0 | tostring) else "0" end)
] | @tsv')

IFS=$'\t' read -r model_full cost lines_added lines_removed session_id cwd ctx_size ctx_current ctx_cache_read <<< "$read_data"

# ─── Model name (shorten "Claude Opus 4.6" → "Opus 4.6") ────────────
if [[ "$model_full" =~ Claude\ ([0-9.]+\ )?(.+) ]]; then
	version="${BASH_REMATCH[1]}"
	name="${BASH_REMATCH[2]}"
	model_short="${name}${version:+ ${version% }}"
else
	model_short="$model_full"
fi

# ─── Session cost ────────────────────────────────────────────────────
cost_display=$(printf '$%.2f' "$cost")

# ─── Session duration (wall-clock via marker file) ───────────────────
SESSION_MARKER_DIR="/tmp/claude-statusline-sessions"
duration_display=""
duration_seconds=0
cost_rate_display=""

if [ -n "$session_id" ]; then
	mkdir -p "$SESSION_MARKER_DIR"
	marker_file="$SESSION_MARKER_DIR/$session_id"
	[ -f "$marker_file" ] || date +%s > "$marker_file"

	session_start=$(cat "$marker_file")
	duration_seconds=$(( $(date +%s) - session_start ))

	if [ "$duration_seconds" -lt 60 ]; then
		duration_display="${duration_seconds}s"
	elif [ "$duration_seconds" -lt 3600 ]; then
		duration_display="$(( duration_seconds / 60 ))m"
	else
		h=$(( duration_seconds / 3600 ))
		m=$(( (duration_seconds % 3600) / 60 ))
		[ "$m" -eq 0 ] && duration_display="${h}h" || duration_display="${h}h${m}m"
	fi

	if [ "$duration_seconds" -gt 60 ] 2>/dev/null; then
		rate=$(awk "BEGIN { printf \"%.2f\", $cost / $duration_seconds * 3600 }")
		cost_rate_display=" ${COLOR_DIM}(${COLOR_COST}\$${rate}/hr${COLOR_DIM})${COLOR_RESET}"
	fi
fi

# ─── Context usage bar ───────────────────────────────────────────────
pct=0
[ "$ctx_size" -gt 0 ] 2>/dev/null && pct=$((ctx_current * 100 / ctx_size))

bar_len=10
filled=$((pct * bar_len / 100))
empty=$((bar_len - filled))

if [ "$pct" -ge 80 ]; then
	bar_color="$COLOR_BAR_CRITICAL"; pct_color="$COLOR_PCT_CRITICAL"; warn=" ⚠️"
elif [ "$pct" -ge 50 ]; then
	bar_color="$COLOR_BAR_WARNING"; pct_color="$COLOR_PCT_WARNING"; warn=""
else
	bar_color="$COLOR_BAR_FULL"; pct_color="$COLOR_PCT"; warn=""
fi

filled_bar=""; empty_bar=""
for ((i = 0; i < filled; i++)); do filled_bar+="█"; done
for ((i = 0; i < empty; i++)); do empty_bar+="░"; done
context_bar="${COLOR_DIM}[${COLOR_RESET}${bar_color}${filled_bar}${COLOR_BAR_EMPTY}${empty_bar}${COLOR_DIM}]${COLOR_RESET} ${pct_color}${pct}%${COLOR_RESET}${warn}"

# ─── Cache hit rate ──────────────────────────────────────────────────
cache_display=""
if [ "$ctx_current" -gt 0 ] 2>/dev/null && [ "$ctx_cache_read" -gt 0 ] 2>/dev/null; then
	cache_pct=$((ctx_cache_read * 100 / ctx_current))
	cache_display=" ${COLOR_CACHE}⚡${cache_pct}%${COLOR_RESET}"
fi

# ─── Git info (cached for performance) ───────────────────────────────
branch=""
is_worktree=false
wt_name=""
sync_display=""
dirty_display=""
commit_age_display=""
base_branch_display=""

if [ -n "$cwd" ] && [ -d "$cwd" ] && { [ -d "$cwd/.git" ] || [ -f "$cwd/.git" ]; }; then
	mkdir -p "$GIT_CACHE_DIR"
	cache_key=$(printf '%s' "$cwd" | md5 -q 2>/dev/null || printf '%s' "$cwd" | md5sum | cut -d' ' -f1)

	# Branch name (cheap — always fetch live)
	branch=$(cd "$cwd" 2>/dev/null && git -c core.useBuiltinFSMonitor=false branch --show-current 2>/dev/null)

	# Worktree detection (cheap)
	git_dir=$(cd "$cwd" 2>/dev/null && git rev-parse --git-dir 2>/dev/null)
	git_common=$(cd "$cwd" 2>/dev/null && git rev-parse --git-common-dir 2>/dev/null)
	if [ -n "$git_dir" ] && [ -n "$git_common" ] && [ "$git_dir" != "$git_common" ]; then
		is_worktree=true
		if [[ "$cwd" =~ (/\.claude/worktrees/|/\.worktrees/|/\.worktree/)([^/]+)(/|$) ]]; then
			wt_name="${BASH_REMATCH[2]}"
		else
			wt_name="${git_dir##*/}"
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
			[ "$behind" -gt 0 ] 2>/dev/null && sync_display+="${COLOR_SYNC_BEHIND}↓${behind}${COLOR_RESET}"
		fi
		echo "$sync_display" > "$sync_cache"
	fi

	if cache_fresh "$dirty_cache" "$GIT_CACHE_TTL"; then
		dirty_display=$(cat "$dirty_cache")
	else
		dirty_display=""
		git_status=$(cd "$cwd" 2>/dev/null && git status --porcelain 2>/dev/null)
		if [ -n "$git_status" ]; then
			staged=$(echo "$git_status" | grep -c '^[MADRC]' 2>/dev/null || echo 0)
			unstaged=$(echo "$git_status" | grep -c '^.[MD]' 2>/dev/null || echo 0)
			untracked=$(echo "$git_status" | grep -c '^??' 2>/dev/null || echo 0)
			[ "$staged" -gt 0 ] && dirty_display+="${COLOR_ADD}●${staged}${COLOR_RESET}"
			[ "$unstaged" -gt 0 ] && dirty_display+="${COLOR_SYNC_AHEAD}◦${unstaged}${COLOR_RESET}"
			[ "$untracked" -gt 0 ] && dirty_display+="${COLOR_DIM}…${untracked}${COLOR_RESET}"
		fi
		echo "$dirty_display" > "$dirty_cache"
	fi

	# Last commit age (cached with git cache TTL)
	commit_cache="$GIT_CACHE_DIR/${cache_key}_commit"
	if cache_fresh "$commit_cache" "$GIT_CACHE_TTL"; then
		commit_age_display=$(cat "$commit_cache")
	else
		commit_epoch=$(cd "$cwd" 2>/dev/null && git log -1 --format=%ct 2>/dev/null)
		commit_age_display=""
		if [ -n "$commit_epoch" ] && [ "$commit_epoch" -gt 0 ] 2>/dev/null; then
			age_secs=$(( $(date +%s) - commit_epoch ))
			commit_age_display=$(format_commit_age "$age_secs")
		fi
		echo "$commit_age_display" > "$commit_cache"
	fi

	# Base branch detection (heavily cached — rarely changes)
	base_cache="$GIT_CACHE_DIR/${cache_key}_base"
	if cache_fresh "$base_cache" "$BASE_CACHE_TTL"; then
		base_branch_display=$(cat "$base_cache")
	else
		base_branch_display=""
		if [ -n "$branch" ]; then
			base_ref=""
			# Check release branches first (Nest convention), then stg, then main
			for ref in $(cd "$cwd" 2>/dev/null && git branch -r --list 'origin/release/*' --sort=-version:refname 2>/dev/null | head -5 | sed 's/^ *//'); do
				mb=$(cd "$cwd" 2>/dev/null && git merge-base "$ref" HEAD 2>/dev/null)
				ref_tip=$(cd "$cwd" 2>/dev/null && git rev-parse "$ref" 2>/dev/null)
				if [ -n "$mb" ] && [ "$mb" = "$ref_tip" -o -n "$(cd "$cwd" 2>/dev/null && git log --oneline "$mb..HEAD" 2>/dev/null | head -1)" ]; then
					base_ref="${ref#origin/}"
					break
				fi
			done
			if [ -z "$base_ref" ]; then
				for try_ref in origin/stg origin/main origin/master; do
					if cd "$cwd" 2>/dev/null && git merge-base "$try_ref" HEAD >/dev/null 2>&1; then
						base_ref="${try_ref#origin/}"
						break
					fi
				done
			fi
			[ -n "$base_ref" ] && base_branch_display="${COLOR_DIM}←${COLOR_BASE}${base_ref}${COLOR_RESET}"
		fi
		echo "$base_branch_display" > "$base_cache"
	fi
fi

# ─── PR detection + CI status (cached) ───────────────────────────────
pr_display=""
ci_display=""
if [ -n "$branch" ] && [ -n "$cwd" ]; then
	mkdir -p "$PR_CACHE_DIR"
	pr_cache_key=$(printf '%s:%s' "$cwd" "$branch" | md5 -q 2>/dev/null || printf '%s:%s' "$cwd" "$branch" | md5sum | cut -d' ' -f1)
	pr_cache_file="$PR_CACHE_DIR/$pr_cache_key"

	if cache_fresh "$pr_cache_file" "$PR_CACHE_TTL"; then
		IFS=$'\t' read -r pr_url pr_state <<< "$(cat "$pr_cache_file")"
	else
		pr_json=$(cd "$cwd" 2>/dev/null && gh pr view "$branch" --json url,state 2>/dev/null || echo "")
		pr_url=""
		pr_state=""
		if [ -n "$pr_json" ]; then
			pr_url=$(echo "$pr_json" | jq -r '.url // ""')
			pr_state=$(echo "$pr_json" | jq -r '.state // ""')
		fi
		printf '%s\t%s' "$pr_url" "$pr_state" > "$pr_cache_file"
	fi

	if [ -n "$pr_url" ]; then
		pr_number="${pr_url##*/}"
		if [ "$pr_state" = "MERGED" ]; then
			pr_display="${COLOR_PR_MERGED}#${pr_number} merged${COLOR_RESET}"
		elif [ "$pr_state" = "OPEN" ]; then
			pr_display="${COLOR_PR}#${pr_number}${COLOR_RESET}"

			# CI status only for open PRs
			ci_cache_file="$PR_CACHE_DIR/${pr_cache_key}_ci"
			if cache_fresh "$ci_cache_file" "$CI_CACHE_TTL"; then
				ci_display=$(cat "$ci_cache_file")
			else
				ci_display=""
				ci_json=$(cd "$cwd" 2>/dev/null && gh pr checks "$branch" --json name,state,conclusion 2>/dev/null || echo "")
				if [ -n "$ci_json" ] && [ "$ci_json" != "[]" ] && [ "$ci_json" != "null" ]; then
					failed=$(echo "$ci_json" | jq '[.[] | select(.conclusion == "FAILURE" or .conclusion == "CANCELLED" or .conclusion == "TIMED_OUT")] | length')
					pending=$(echo "$ci_json" | jq '[.[] | select(.state == "PENDING" or .state == "QUEUED" or .state == "IN_PROGRESS")] | length')
					passed=$(echo "$ci_json" | jq '[.[] | select(.conclusion == "SUCCESS" or .conclusion == "NEUTRAL" or .conclusion == "SKIPPED")] | length')

					if [ "$failed" -gt 0 ] 2>/dev/null; then
						ci_display="${COLOR_CI_FAIL}✗${COLOR_RESET}"
					elif [ "$pending" -gt 0 ] 2>/dev/null; then
						ci_display="${COLOR_CI_PENDING}⏳${COLOR_RESET}"
					elif [ "$passed" -gt 0 ] 2>/dev/null; then
						ci_display="${COLOR_CI_PASS}✓${COLOR_RESET}"
					fi
				fi
				echo "$ci_display" > "$ci_cache_file"
			fi
		elif [ "$pr_state" = "CLOSED" ]; then
			pr_display="${COLOR_DIM}#${pr_number} closed${COLOR_RESET}"
		fi
	fi
fi

# ─── Lines changed this session ──────────────────────────────────────
lines_display=""
if [ "$lines_added" -gt 0 ] 2>/dev/null || [ "$lines_removed" -gt 0 ] 2>/dev/null; then
	parts=""
	[ "$lines_added" -gt 0 ] && parts+="${COLOR_ADD}+${lines_added}${COLOR_RESET}"
	[ "$lines_removed" -gt 0 ] && parts+=" ${COLOR_DEL}-${lines_removed}${COLOR_RESET}"
	lines_display="$parts"
fi

# ─── Assemble output ─────────────────────────────────────────────────
sep=" ${COLOR_DIM}·${COLOR_RESET} "

# Line 1: session vitals + PR + CI
line1="${COLOR_MODEL}${model_short}${COLOR_RESET}"
line1+="${sep}${COLOR_COST}${cost_display}${COLOR_RESET}"
[ -n "$cost_rate_display" ] && line1+="${cost_rate_display}"
[ -n "$duration_display" ] && line1+="${sep}${COLOR_DUR}${duration_display}${COLOR_RESET}"
line1+="   ${context_bar}${cache_display}"
if [ -n "$pr_display" ]; then
	line1+="  ${pr_display}"
	[ -n "$ci_display" ] && line1+=" ${ci_display}"
fi

# Line 2: [worktree]  branch ←base  sync dirty  ·  commit-age  +N -N
line2=""

# Identity zone: worktree + branch + base + sync + dirty
if [ "$is_worktree" = true ]; then
	line2+="${COLOR_DIM}🌿 ${wt_name}${COLOR_RESET}"
fi
if [ -n "$branch" ]; then
	[ -n "$line2" ] && line2+="  "
	line2+="${COLOR_GIT}${branch}${COLOR_RESET}"
	[ -n "$base_branch_display" ] && line2+=" ${base_branch_display}"
	[ -n "$sync_display" ] && line2+=" ${sync_display}"
	[ -n "$dirty_display" ] && line2+=" ${dirty_display}"
fi

# Status zone: commit age + diff stats (separated by ·)
status_parts=""
[ -n "$commit_age_display" ] && status_parts+="${commit_age_display}"
if [ -n "$lines_display" ]; then
	[ -n "$status_parts" ] && status_parts+="  "
	status_parts+="${lines_display}"
fi
if [ -n "$status_parts" ] && [ -n "$line2" ]; then
	line2+="${sep}${status_parts}"
elif [ -n "$status_parts" ]; then
	line2+="${status_parts}"
fi

if [ -z "$line2" ] && [ -n "$cwd" ]; then
	display_cwd="${cwd/#$HOME/~}"
	line2="${COLOR_DIM}${display_cwd}${COLOR_RESET}"
fi

# Print
printf "%b\n" "$line1"
[ -n "$line2" ] && printf "%b\n" "$line2"
