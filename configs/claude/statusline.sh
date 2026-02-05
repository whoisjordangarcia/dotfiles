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
COLOR_RESET=$'\033[0m'

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

# Session cost
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
cost_display=$(printf '$%.2f' "$cost")

# Session duration
session_id=$(echo "$input" | jq -r '.session_id // ""')
duration_display=""
if [ -n "$session_id" ]; then
	# Extract timestamp from session_id (format: YYYYMMDD-HHMMSS-randomchars)
	if [[ "$session_id" =~ ^([0-9]{8})-([0-9]{6}) ]]; then
		date_part="${BASH_REMATCH[1]}"
		time_part="${BASH_REMATCH[2]}"

		# Convert to timestamp format: YYYYMMDDHHMMSS
		session_start_str="${date_part}${time_part}"

		# Parse into components
		year="${session_start_str:0:4}"
		month="${session_start_str:4:2}"
		day="${session_start_str:6:2}"
		hour="${session_start_str:8:2}"
		minute="${session_start_str:10:2}"
		second="${session_start_str:12:2}"

		# Convert to epoch time (macOS compatible date command)
		session_start_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$year-$month-$day $hour:$minute:$second" "+%s" 2>/dev/null)

		if [ -n "$session_start_epoch" ]; then
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
		fi
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

# Git branch and worktree path
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')
if [ -n "$cwd" ] && [ -d "$cwd/.git" ]; then
	branch=$(cd "$cwd" 2>/dev/null && git -c core.useBuiltinFSMonitor=false branch --show-current 2>/dev/null)
	if [ -n "$branch" ]; then
		git_info=" ${COLOR_SEPARATOR}|${COLOR_RESET} ${COLOR_GIT}${branch}${COLOR_RESET}"
	else
		git_info=""
	fi
else
	git_info=""
fi

# Worktree path for second line - extract portion after .worktrees/
worktree_path="$cwd"
if [[ "$worktree_path" =~ \.worktrees/(.+)$ ]]; then
	worktree_path="${BASH_REMATCH[1]}"
fi

# Output with colors
# Using %b for context_info and git_info since they contain embedded escape codes
if [ -n "$duration_display" ]; then
	printf "%s%s%s %s|%s %s%s%s %s|%s %s%s%s %s|%s %b %s|%s %s%s%s%b\n%s%s%s\n" \
		"$COLOR_MODEL" "$model_short" "$COLOR_RESET" \
		"$COLOR_SEPARATOR" "$COLOR_RESET" \
		"$COLOR_COST" "$cost_display" "$COLOR_RESET" \
		"$COLOR_SEPARATOR" "$COLOR_RESET" \
		"$COLOR_DURATION" "$duration_display" "$COLOR_RESET" \
		"$COLOR_SEPARATOR" "$COLOR_RESET" \
		"$context_info" \
		"$COLOR_SEPARATOR" "$COLOR_RESET" \
		"$COLOR_TOKENS" "$tokens_display" "$COLOR_RESET" \
		"$git_info" \
		"$COLOR_ITALIC" "$worktree_path" "$COLOR_RESET"
else
	printf "%s%s%s %s|%s %s%s%s %s|%s %b %s|%s %s%s%s%b\n%s%s%s\n" \
		"$COLOR_MODEL" "$model_short" "$COLOR_RESET" \
		"$COLOR_SEPARATOR" "$COLOR_RESET" \
		"$COLOR_COST" "$cost_display" "$COLOR_RESET" \
		"$COLOR_SEPARATOR" "$COLOR_RESET" \
		"$context_info" \
		"$COLOR_SEPARATOR" "$COLOR_RESET" \
		"$COLOR_TOKENS" "$tokens_display" "$COLOR_RESET" \
		"$git_info" \
		"$COLOR_ITALIC" "$worktree_path" "$COLOR_RESET"
fi
