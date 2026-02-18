#!/bin/bash

input=$(cat)

# Color definitions (elegant, subtle palette)
# Using $'...' syntax so escape sequences are interpreted
COLOR_MODEL=$'\033[38;5;141m'      # Soft purple for model
COLOR_COST=$'\033[38;5;114m'       # Soft green for cost
COLOR_BAR_FULL=$'\033[38;5;110m'   # Blue-gray for filled bar
COLOR_BAR_WARNING=$'\033[38;5;221m'  # Yellow for warning (50%+)
COLOR_BAR_CRITICAL=$'\033[38;5;196m' # Red for critical (80%+)
COLOR_BAR_EMPTY=$'\033[38;5;240m'  # Dark gray for empty bar
COLOR_PERCENT=$'\033[38;5;147m'    # Light blue for percentage
COLOR_PERCENT_WARNING=$'\033[38;5;221m'  # Yellow for warning
COLOR_PERCENT_CRITICAL=$'\033[38;5;196m' # Red for critical
COLOR_TOKENS=$'\033[38;5;180m'     # Soft gold for tokens
COLOR_DURATION=$'\033[38;5;183m'   # Soft pink for duration
COLOR_GIT=$'\033[38;5;173m'        # Soft coral for git branch
COLOR_SEPARATOR=$'\033[38;5;238m'  # Subtle gray for separators
COLOR_ITALIC=$'\033[3m'            # Italic text
COLOR_PR=$'\033[38;5;75m'          # Light blue for PR link
COLOR_SYNC_OK=$'\033[38;5;114m'    # Green for synced
COLOR_SYNC_AHEAD=$'\033[38;5;221m' # Yellow for needs push
COLOR_SYNC_BEHIND=$'\033[38;5;209m' # Orange for needs pull
COLOR_SYNC_DIVERGED=$'\033[38;5;196m' # Red for diverged
COLOR_LINES_ADD=$'\033[38;5;114m'  # Green for lines added
COLOR_LINES_DEL=$'\033[38;5;203m'  # Red for lines removed
COLOR_RESET=$'\033[0m'

PR_CACHE_DIR="/tmp/claude-statusline-pr-cache"
PR_CACHE_TTL=300  # 5 minutes

# Extract model and shorten it
model_full=$(echo "$input" | jq -r '.model.display_name // "Unknown"')

# Shorten model name (e.g., "Claude 3.5 Sonnet" -> "Sonnet 3.5", "Claude Opus 4.5" -> "Opus 4.5")
if [[ "$model_full" =~ Claude\ ([0-9.]+\ )?(.+) ]]; then
	version="${BASH_REMATCH[1]}"
	name="${BASH_REMATCH[2]}"
	if [ -n "$version" ]; then
		model_short="$name $version"
	else
		model_short="$name"
	fi
else
	model_short="$model_full"
fi

# Remove trailing space
model_short=$(echo "$model_short" | sed 's/ $//')

# Session cost + cost rate
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
cost_display=$(printf '$%.2f' "$cost")
cost_rate_display=""

# Session duration — use marker file for reliable wall-clock tracking
SESSION_MARKER_DIR="/tmp/claude-statusline-sessions"
session_id=$(echo "$input" | jq -r '.session_id // ""')
duration_display=""
duration_seconds=0
if [ -n "$session_id" ]; then
	mkdir -p "$SESSION_MARKER_DIR"
	marker_file="$SESSION_MARKER_DIR/$session_id"

	if [ ! -f "$marker_file" ]; then
		# First run for this session — record start time
		date +%s > "$marker_file"
	fi

	session_start_epoch=$(cat "$marker_file")
	current_epoch=$(date +%s)
	duration_seconds=$((current_epoch - session_start_epoch))

	# Format duration
	if [ "$duration_seconds" -lt 60 ]; then
		duration_display="${duration_seconds}s"
	elif [ "$duration_seconds" -lt 3600 ]; then
		minutes=$((duration_seconds / 60))
		duration_display="${minutes}m"
	else
		hours=$((duration_seconds / 3600))
		remaining_minutes=$(((duration_seconds % 3600) / 60))
		if [ "$remaining_minutes" -eq 0 ]; then
			duration_display="${hours}h"
		else
			duration_display="${hours}h ${remaining_minutes}m"
		fi
	fi

	# Cost rate ($/hr) - only show after 60s to avoid wild early numbers
	if [ "$duration_seconds" -gt 60 ] 2>/dev/null; then
		cost_rate=$(awk "BEGIN { printf \"%.2f\", $cost / $duration_seconds * 3600 }")
		cost_rate_display=" ${COLOR_SEPARATOR}(${COLOR_RESET}${COLOR_COST}\$${cost_rate}/hr${COLOR_RESET}${COLOR_SEPARATOR})${COLOR_RESET}"
	fi
fi

# Context usage
usage=$(echo "$input" | jq '.context_window.current_usage')
if [ "$usage" != "null" ]; then
	current=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
	size=$(echo "$input" | jq '.context_window.context_window_size // 0')

	# Guard against division by zero
	if [ "$size" -gt 0 ] 2>/dev/null; then
		pct=$((current * 100 / size))
	else
		pct=0
	fi

	# Progress bar with colors - determine color based on usage percentage
	bar_length=10
	filled=$((pct * bar_length / 100))
	empty=$((bar_length - filled))

	# Determine bar and percentage color based on thresholds
	if [ "$pct" -ge 80 ]; then
		bar_color="$COLOR_BAR_CRITICAL"
		pct_color="$COLOR_PERCENT_CRITICAL"
		critical_indicator=" ⚠️"
	elif [ "$pct" -ge 50 ]; then
		bar_color="$COLOR_BAR_WARNING"
		pct_color="$COLOR_PERCENT_WARNING"
		critical_indicator=""
	else
		bar_color="$COLOR_BAR_FULL"
		pct_color="$COLOR_PERCENT"
		critical_indicator=""
	fi

	# Build filled and empty portions separately for proper coloring
	filled_bar=""
	empty_bar=""
	for ((i = 0; i < filled; i++)); do filled_bar+="█"; done
	for ((i = 0; i < empty; i++)); do empty_bar+="░"; done

	context_info="[${bar_color}${filled_bar}${COLOR_BAR_EMPTY}${empty_bar}${COLOR_RESET}] ${pct_color}${pct}%${COLOR_RESET}${critical_indicator}"

	# Format tokens (k for thousands)
	current=${current:-0}
	size=${size:-0}

	if [ "$current" -ge 1000 ] 2>/dev/null; then
		current_k=$((current / 1000))
		current_display="${current_k}k"
	else
		current_display="${current}"
	fi

	if [ "$size" -ge 1000 ] 2>/dev/null; then
		size_k=$((size / 1000))
		size_display="${size_k}k"
	else
		size_display="${size}"
	fi

	tokens_display="${current_display}/${size_display} tokens"
else
	context_info="[${COLOR_BAR_EMPTY}░░░░░░░░░░${COLOR_RESET}] ${COLOR_PERCENT}0%${COLOR_RESET}"
	size=$(echo "$input" | jq '.context_window.context_window_size // 0')
	if [ "$size" -ge 1000 ] 2>/dev/null; then
		size_k=$((size / 1000))
		size_display="${size_k}k"
	else
		size_display="${size}"
	fi
	tokens_display="0/${size_display} tokens"
fi

# Git branch, worktree detection, and path
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')
COLOR_WORKTREE=$'\033[38;5;114m'   # Soft green for worktree indicator
git_info=""
worktree_indicator=""
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
	# -d .git = normal repo, -f .git = worktree (git writes a file pointing to the main repo)
	if [ -d "$cwd/.git" ] || [ -f "$cwd/.git" ]; then
		branch=$(cd "$cwd" 2>/dev/null && git -c core.useBuiltinFSMonitor=false branch --show-current 2>/dev/null)
		if [ -n "$branch" ]; then
			# Sync status: ahead/behind upstream
			sync_display=""
			upstream_info=$(cd "$cwd" 2>/dev/null && git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
			if [ -n "$upstream_info" ]; then
				ahead=$(echo "$upstream_info" | awk '{print $1}')
				behind=$(echo "$upstream_info" | awk '{print $2}')
				if [ "$ahead" -gt 0 ] 2>/dev/null && [ "$behind" -gt 0 ] 2>/dev/null; then
					sync_display=" ${COLOR_SYNC_AHEAD}↑${ahead}${COLOR_SYNC_BEHIND}↓${behind}${COLOR_RESET}"
				elif [ "$ahead" -gt 0 ] 2>/dev/null; then
					sync_display=" ${COLOR_SYNC_AHEAD}↑${ahead}${COLOR_RESET}"
				elif [ "$behind" -gt 0 ] 2>/dev/null; then
					sync_display=" ${COLOR_SYNC_BEHIND}↓${behind}${COLOR_RESET}"
				fi
			fi

			# Working tree status: staged/unstaged/untracked
			dirty_display=""
			git_status=$(cd "$cwd" 2>/dev/null && git status --porcelain 2>/dev/null)
			if [ -n "$git_status" ]; then
				staged=$(echo "$git_status" | grep -c '^[MADRC]' 2>/dev/null || echo 0)
				unstaged=$(echo "$git_status" | grep -c '^.[MD]' 2>/dev/null || echo 0)
				untracked=$(echo "$git_status" | grep -c '^??' 2>/dev/null || echo 0)
				parts=""
				[ "$staged" -gt 0 ] && parts="${parts}${COLOR_SYNC_OK}+${staged}${COLOR_RESET}"
				[ "$unstaged" -gt 0 ] && parts="${parts}${COLOR_SYNC_AHEAD}!${unstaged}${COLOR_RESET}"
				[ "$untracked" -gt 0 ] && parts="${parts}${COLOR_SEPARATOR}?${untracked}${COLOR_RESET}"
				[ -n "$parts" ] && dirty_display=" ${parts}"
			fi

			git_info=" ${COLOR_SEPARATOR}|${COLOR_RESET} ${COLOR_GIT}${branch}${COLOR_RESET}${sync_display}${dirty_display}"
		fi

		# Detect worktree: git-dir differs from git-common-dir in worktrees
		git_dir=$(cd "$cwd" 2>/dev/null && git rev-parse --git-dir 2>/dev/null)
		git_common=$(cd "$cwd" 2>/dev/null && git rev-parse --git-common-dir 2>/dev/null)
		if [ -n "$git_dir" ] && [ -n "$git_common" ] && [ "$git_dir" != "$git_common" ]; then
			# Extract worktree name from known path patterns or fall back to git-dir
			if [[ "$cwd" =~ (/\.claude/worktrees/|/\.worktrees/|/\.worktree/)([^/]+)(/|$) ]]; then
				wt_name="${BASH_REMATCH[2]}"
			else
				wt_name="${git_dir##*/}"
			fi
			worktree_indicator=" ${COLOR_WORKTREE}🌿 .worktree/${wt_name}${COLOR_RESET}"
		fi
	fi
fi

# PR detection with cache (avoids hitting GitHub API on every refresh)
pr_info=""
if [ -n "$branch" ] && [ -n "$cwd" ]; then
	mkdir -p "$PR_CACHE_DIR"
	# Cache key: repo path + branch name (hashed to avoid path issues)
	cache_key=$(printf '%s:%s' "$cwd" "$branch" | md5 -q 2>/dev/null || printf '%s:%s' "$cwd" "$branch" | md5sum | cut -d' ' -f1)
	cache_file="$PR_CACHE_DIR/$cache_key"

	# Check if cache is fresh
	cache_valid=false
	if [ -f "$cache_file" ]; then
		cache_age=$(( $(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null || echo 0) ))
		if [ "$cache_age" -lt "$PR_CACHE_TTL" ]; then
			cache_valid=true
		fi
	fi

	if [ "$cache_valid" = true ]; then
		pr_url=$(cat "$cache_file")
	else
		# Query GitHub for open PR on this branch
		pr_url=$(cd "$cwd" 2>/dev/null && gh pr view "$branch" --json url,state -q 'select(.state == "OPEN") | .url' 2>/dev/null || echo "")
		echo "$pr_url" > "$cache_file"
	fi

	if [ -n "$pr_url" ]; then
		# Extract PR number and short repo path (e.g., Nest-Genomics/nest#2495)
		pr_number="${pr_url##*/}"
		# Extract org/repo from URL: https://github.com/org/repo/pull/123
		if [[ "$pr_url" =~ github\.com/([^/]+/[^/]+)/pull/ ]]; then
			pr_display="${BASH_REMATCH[1]}#${pr_number}"
		else
			pr_display="#${pr_number}"
		fi
		pr_info=" ${COLOR_SEPARATOR}|${COLOR_RESET} ${COLOR_PR}${pr_display}${COLOR_RESET}"
	fi
fi

# Lines changed this session
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
lines_display=""
if [ "$lines_added" -gt 0 ] 2>/dev/null || [ "$lines_removed" -gt 0 ] 2>/dev/null; then
	parts=""
	[ "$lines_added" -gt 0 ] && parts="${COLOR_LINES_ADD}+${lines_added}${COLOR_RESET}"
	[ "$lines_removed" -gt 0 ] && parts="${parts} ${COLOR_LINES_DEL}-${lines_removed}${COLOR_RESET}"
	lines_display=" ${COLOR_SEPARATOR}│${COLOR_RESET} ${parts}"
fi

# Build second line: worktree gets 🌿 prefix, normal repo shows full path
if [ -n "$worktree_indicator" ]; then
	second_line="${COLOR_WORKTREE}🌿 .worktree/${wt_name}${COLOR_RESET}${lines_display}"
else
	# Shorten home directory to ~
	display_cwd="${cwd/#$HOME/~}"
	second_line="${COLOR_ITALIC}${display_cwd}${COLOR_RESET}${lines_display}"
fi

# Output with colors
# Using %b for context_info, git_info, pr_info, and second_line since they contain embedded escape codes
if [ -n "$duration_display" ]; then
	printf "%s%s%s %s|%s %s%s%s%b %s|%s %s%s%s %s|%s %b %s|%s %s%s%s%b%b\n%b\n" \
		"$COLOR_MODEL" "$model_short" "$COLOR_RESET" \
		"$COLOR_SEPARATOR" "$COLOR_RESET" \
		"$COLOR_COST" "$cost_display" "$COLOR_RESET" \
		"$cost_rate_display" \
		"$COLOR_SEPARATOR" "$COLOR_RESET" \
		"$COLOR_DURATION" "$duration_display" "$COLOR_RESET" \
		"$COLOR_SEPARATOR" "$COLOR_RESET" \
		"$context_info" \
		"$COLOR_SEPARATOR" "$COLOR_RESET" \
		"$COLOR_TOKENS" "$tokens_display" "$COLOR_RESET" \
		"$git_info" \
		"$pr_info" \
		"$second_line"
else
	printf "%s%s%s %s|%s %s%s%s%b %s|%s %b %s|%s %s%s%s%b%b\n%b\n" \
		"$COLOR_MODEL" "$model_short" "$COLOR_RESET" \
		"$COLOR_SEPARATOR" "$COLOR_RESET" \
		"$COLOR_COST" "$cost_display" "$COLOR_RESET" \
		"$cost_rate_display" \
		"$COLOR_SEPARATOR" "$COLOR_RESET" \
		"$context_info" \
		"$COLOR_SEPARATOR" "$COLOR_RESET" \
		"$COLOR_TOKENS" "$tokens_display" "$COLOR_RESET" \
		"$git_info" \
		"$pr_info" \
		"$second_line"
fi
