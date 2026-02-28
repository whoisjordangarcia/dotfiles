#!/bin/bash

input=$(cat)

# ─── Colors (soft purple theme) ──────────────────────────────────────
COLOR_ACCENT=$'\033[38;5;141m'         # Soft purple — primary accent
COLOR_WHITE=$'\033[38;5;255m'          # White — key data
COLOR_DIM=$'\033[38;5;245m'            # Medium gray — secondary info
COLOR_ADD=$'\033[38;5;114m'            # Green — positive (additions, pass, fresh)
COLOR_DEL=$'\033[38;5;203m'            # Red — negative (deletions, fail, critical)
COLOR_WARN=$'\033[38;5;221m'           # Yellow — warnings, stale
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
COLOR_DUR="$COLOR_DIM"
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
COLOR_DOCKER="$COLOR_ADD"
COLOR_DOCKER_OFF="$COLOR_DIM"

# ─── Cache config ────────────────────────────────────────────────────
GIT_CACHE_DIR="/tmp/claude-statusline-git-cache"
GIT_CACHE_TTL=10    # seconds
PR_CACHE_DIR="/tmp/claude-statusline-pr-cache"
PR_CACHE_TTL=300    # 5 minutes
CI_CACHE_TTL=120    # 2 minutes — CI changes more often than PR metadata
BASE_CACHE_TTL=600  # 10 minutes — base branch rarely changes
DOCKER_CACHE_DIR="/tmp/claude-statusline-docker-cache"
DOCKER_CACHE_TTL=30  # 30 seconds — containers can start/stop frequently

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
		[ "$m" -gt 0 ] && label="${h}h ${m}m ago" || label="${h}h ago"
		color="$COLOR_COMMIT_OLD"
	else
		label="$(( secs / 86400 ))d ago"; color="$COLOR_COMMIT_OLD"
	fi
	echo "${COLOR_DIM}${label} since commit${COLOR_RESET}"
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
		[ "$m" -eq 0 ] && duration_display="${h}h" || duration_display="${h}h ${m}m"
	fi

	if [ "$duration_seconds" -gt 300 ] 2>/dev/null; then
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
			[ "$behind" -gt 0 ] 2>/dev/null && { [ -n "$sync_display" ] && sync_display+=" "; sync_display+="${COLOR_SYNC_BEHIND}↓${behind}${COLOR_RESET}"; }
		fi
		echo "$sync_display" > "$sync_cache"
	fi

	if cache_fresh "$dirty_cache" "$GIT_CACHE_TTL"; then
		dirty_display=$(cat "$dirty_cache")
	else
		dirty_display=""
		git_status=$(cd "$cwd" 2>/dev/null && git status --porcelain 2>/dev/null)
		if [ -n "$git_status" ]; then
			staged=$(grep -c '^[MADRC]' <<< "$git_status" 2>/dev/null) || staged=0
			unstaged=$(grep -c '^.[MD]' <<< "$git_status" 2>/dev/null) || unstaged=0
			untracked=$(grep -c '^??' <<< "$git_status" 2>/dev/null) || untracked=0
			[ "$staged" -gt 0 ] && dirty_display+="${COLOR_ADD}● ${staged} staged${COLOR_RESET}"
			[ "$unstaged" -gt 0 ] && { [ -n "$dirty_display" ] && dirty_display+=" "; dirty_display+="${COLOR_SYNC_AHEAD}◦ ${unstaged} modified${COLOR_RESET}"; }
			[ "$untracked" -gt 0 ] && { [ -n "$dirty_display" ] && dirty_display+=" "; dirty_display+="${COLOR_CACHE}+${untracked} new${COLOR_RESET}"; }
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
			if [ "$age_secs" -lt 18000 ]; then
				commit_age_display=$(format_commit_age "$age_secs")
			fi
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
			# Filter to only semver release branches (e.g. release/2.15.0), skip suffixed ones like release/2.15.0-stg-sync
			for ref in $(cd "$cwd" 2>/dev/null && git branch -r --list 'origin/release/*' --sort=-version:refname 2>/dev/null | grep -E '/release/[0-9]+\.[0-9]+\.[0-9]+$' | head -5 | sed 's/^ *//'); do
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
			[ -n "$base_ref" ] && [ "$base_ref" != "$branch" ] && base_branch_display="${COLOR_DIM}← ${COLOR_BASE}${base_ref}${COLOR_RESET}"
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
		IFS=$'\t' read -r pr_url pr_state pr_draft <<< "$(cat "$pr_cache_file")"
	else
		pr_json=$(cd "$cwd" 2>/dev/null && gh pr view "$branch" --json url,state,isDraft 2>/dev/null || echo "")
		pr_url=""
		pr_state=""
		pr_draft=""
		if [ -n "$pr_json" ]; then
			pr_url=$(echo "$pr_json" | jq -r '.url // ""')
			pr_state=$(echo "$pr_json" | jq -r '.state // ""')
			pr_draft=$(echo "$pr_json" | jq -r '.isDraft // false')
		fi
		printf '%s\t%s\t%s' "$pr_url" "$pr_state" "$pr_draft" > "$pr_cache_file"
	fi

	if [ -n "$pr_url" ]; then
		pr_number="${pr_url##*/}"
		if [ "$pr_state" = "MERGED" ]; then
			pr_display="${COLOR_PR_MERGED} #${pr_number} merged${COLOR_RESET}"
		elif [ "$pr_state" = "OPEN" ] && [ "$pr_draft" = "true" ]; then
			pr_display="${COLOR_PR_DRAFT} #${pr_number} draft${COLOR_RESET}"

			# CI status for draft PRs too
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
		elif [ "$pr_state" = "OPEN" ]; then
			pr_display="${COLOR_PR_OPEN} #${pr_number}${COLOR_RESET}"

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
			pr_display="${COLOR_DIM} #${pr_number} closed${COLOR_RESET}"
		fi
	fi
fi

# ─── Lines changed this session ──────────────────────────────────────
lines_display=""
if [ "$lines_added" -gt 0 ] 2>/dev/null || [ "$lines_removed" -gt 0 ] 2>/dev/null; then
	parts=""
	[ "$lines_added" -gt 0 ] && parts+="${COLOR_ADD}+${lines_added}${COLOR_RESET}"
	[ "$lines_removed" -gt 0 ] && parts+=" ${COLOR_DEL}-${lines_removed}${COLOR_RESET}"
	lines_display="${parts} ${COLOR_DIM}written${COLOR_RESET}"
fi

# ─── Assemble output ─────────────────────────────────────────────────
sep=" ${COLOR_DIM}·${COLOR_RESET} "

# Line 1: session vitals + commit age
line1="${COLOR_COST}${cost_display}${COLOR_RESET}"
if [[ ! "$model_short" =~ ^Opus ]]; then
	line1="${COLOR_MODEL}${model_short}${COLOR_RESET}${sep}${line1}"
fi
[ -n "$cost_rate_display" ] && line1+="${cost_rate_display}"
[ -n "$duration_display" ] && line1+="${sep}${COLOR_DUR}${duration_display}${COLOR_RESET}"
line1+="${sep}${context_bar}${cache_display}"
[ -n "$commit_age_display" ] && line1+="${sep}${commit_age_display}"

# Line 2: 🌿 branch ←base  sync  dirty  🐳 docker  ⬡ node
line2=""
docker_display=""
node_display=""

# Project name: use main repo name when in a worktree, else cwd basename
project_name=""
if [ "$is_worktree" = true ] && [ -n "$git_common" ]; then
	main_repo=$(cd "$cwd" 2>/dev/null && cd "$git_common/.." 2>/dev/null && pwd)
	[ -n "$main_repo" ] && project_name="${main_repo##*/}"
elif [ -n "$cwd" ]; then
	project_name="${cwd##*/}"
fi

if [ -n "$branch" ]; then
	[ -n "$project_name" ] && line2+="${COLOR_WHITE}${project_name}${COLOR_RESET}${sep}"
	# Worktree indicator: ⎇ #PR (color-coded by state + CI) or ⎇ wt-name
	if [ "$is_worktree" = true ] && [ -n "$wt_name" ]; then
		if [ -n "$pr_number" ]; then
			# Color ⎇ #PR by state: green=open, gray=draft, purple=merged, dim=closed
			pr_color="$COLOR_PR_OPEN"
			if [ "$pr_state" = "MERGED" ]; then
				pr_color="$COLOR_PR_MERGED"
			elif [ "$pr_state" = "OPEN" ] && [ "$pr_draft" = "true" ]; then
				pr_color="$COLOR_PR_DRAFT"
			elif [ "$pr_state" = "CLOSED" ]; then
				pr_color="$COLOR_DIM"
			fi
			line2+="${pr_color}⎇ #${pr_number}${COLOR_RESET}${sep}"
		else
			norm_wt=$(echo "$wt_name" | tr '/' '-')
			norm_br=$(echo "$branch" | tr '/' '-')
			[ "$norm_wt" != "$norm_br" ] && line2+="${COLOR_WORKTREE}⎇ ${wt_name}${COLOR_RESET}${sep}"
		fi
	elif [ -n "$pr_url" ]; then
		# Non-worktree but has PR: show color-coded PR indicator
		pr_color="$COLOR_PR_OPEN"
		if [ "$pr_state" = "MERGED" ]; then
			pr_color="$COLOR_PR_MERGED"
		elif [ "$pr_state" = "OPEN" ] && [ "$pr_draft" = "true" ]; then
			pr_color="$COLOR_PR_DRAFT"
		elif [ "$pr_state" = "CLOSED" ]; then
			pr_color="$COLOR_DIM"
		fi
		line2+="${pr_color}#${pr_number}${COLOR_RESET}${sep}"
	fi
	line2+="${COLOR_DIM}🌿 ${COLOR_GIT}${branch}${COLOR_RESET}"
	[ -n "$base_branch_display" ] && line2+=" ${base_branch_display}"
	[ -n "$sync_display" ] && line2+="${sep}${sync_display}"
	[ -n "$dirty_display" ] && line2+="${sep}${dirty_display}"
fi

if [ -z "$line2" ] && [ -n "$cwd" ]; then
	# No git — show full path with ~ shorthand
	display_path="${cwd/#$HOME/~}"
	line2="${COLOR_WHITE}${display_path}${COLOR_RESET}"
fi

# Lines changed always shows on line 2 (session-level, not git-specific)
[ -n "$lines_display" ] && { [ -n "$line2" ] && line2+="${sep}"; line2+="${lines_display}"; }

# Docker + Node detection (only when in a worktree)
if [ "$is_worktree" = true ]; then
	mkdir -p "$DOCKER_CACHE_DIR"
	wt_cache_key=$(printf '%s' "$wt_name" | md5 -q 2>/dev/null || printf '%s' "$wt_name" | md5sum | cut -d' ' -f1)

	# Docker container detection for this worktree
	if command -v docker &>/dev/null; then
		docker_cache_key="$wt_cache_key"
		docker_cache_file="$DOCKER_CACHE_DIR/$docker_cache_key"

		if cache_fresh "$docker_cache_file" "$DOCKER_CACHE_TTL"; then
			docker_display=$(cat "$docker_cache_file")
		else
			running_containers=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -F "$wt_name" || true)
			if [ -n "$running_containers" ]; then
				# Extract service names (last segment after worktree name)
				services=""
				while IFS= read -r container; do
					svc="${container##*"${wt_name}"-}"
					[ -n "$services" ] && services+=","
					services+="$svc"
				done <<< "$running_containers"
				docker_display="${COLOR_DOCKER}🐳 ${services}${COLOR_RESET}"
			fi
			echo "$docker_display" > "$docker_cache_file"
		fi
	fi
	[ -n "$docker_display" ] && line2+="${sep}${docker_display}"

	# Node app detection for this worktree (apps listening on ports)
	if [ -n "$cwd" ]; then
		node_cache_file="$DOCKER_CACHE_DIR/${wt_cache_key}_node"

		if cache_fresh "$node_cache_file" "$DOCKER_CACHE_TTL"; then
			node_display=$(cat "$node_cache_file")
		else
			# Get all node PIDs listening on TCP ports
			listening=$(lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | awk '$1 == "node" && $2 ~ /^[0-9]+$/ {print $2, $9}' | sort -u)
			app_entries=""
			if [ -n "$listening" ]; then
				while read -r l_pid l_addr; do
					l_port=$(echo "$l_addr" | grep -oE '[0-9]+$')
					[ -z "$l_port" ] && continue
					# Check if this process belongs to our worktree via args OR cwd
					proc_args=$(ps -p "$l_pid" -o args= 2>/dev/null || true)
					proc_cwd=$(lsof -p "$l_pid" -a -d cwd -Fn 2>/dev/null | grep '^n/' | head -1 | cut -c2-)
					in_worktree=false
					if echo "$proc_args" | grep -qF "$cwd"; then
						in_worktree=true
					elif [ -n "$proc_cwd" ] && echo "$proc_cwd" | grep -qF "$cwd"; then
						in_worktree=true
					fi
					[ "$in_worktree" = false ] && continue
					# Extract app name from args or cwd path
					app_name=""
					combined="$proc_args $proc_cwd"
					if echo "$combined" | grep -qE 'apps/backend/[^/]+/dist'; then
						app_name=$(echo "$combined" | sed -n 's|.*apps/backend/\([^/]*\)/dist.*|\1|p' | head -1)
					elif echo "$combined" | grep -qE 'apps/frontend/[^/]+'; then
						app_name=$(echo "$combined" | sed -n 's|.*apps/frontend/\([^/]*\).*|\1|p' | head -1)
					elif echo "$proc_args" | grep -qE 'nx\.js run [^:]+:'; then
						app_name=$(echo "$proc_args" | sed -n 's|.*nx\.js run \([^:]*\):.*|\1|p')
					fi
					[ -n "$app_name" ] && app_entries="${app_entries}${app_name}:${l_port}\n"
				done <<< "$listening"
			fi
			if [ -n "$app_entries" ]; then
				parts=$(printf '%b' "$app_entries" | sort -u -t: -k1,1 | tr '\n' ',' | sed 's/,$//')
				node_display="${COLOR_DOCKER}⬡ ${parts}${COLOR_RESET}"
			fi
			echo "$node_display" > "$node_cache_file"
		fi
	fi
	[ -n "$node_display" ] && line2+="${sep}${node_display}"
fi

# Print
printf "%b\n" "$line1"
[ -n "$line2" ] && printf "%b\n" "$line2"

exit 0
