#!/bin/bash

input=$(cat)

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

# Context usage
usage=$(echo "$input" | jq '.context_window.current_usage')
if [ "$usage" != "null" ]; then
	current=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
	size=$(echo "$input" | jq '.context_window.context_window_size')
	pct=$((current * 100 / size))

	# Progress bar
	bar_length=10
	filled=$((pct * bar_length / 100))
	empty=$((bar_length - filled))

	bar=""
	for ((i = 0; i < filled; i++)); do bar+="█"; done
	for ((i = 0; i < empty; i++)); do bar+="░"; done

	context_info="[$bar] ${pct}%"

	# Format tokens (k for thousands)
	if [ "$current" -ge 1000 ]; then
		current_k=$((current / 1000))
		current_display="${current_k}k"
	else
		current_display="${current}"
	fi

	if [ "$size" -ge 1000 ]; then
		size_k=$((size / 1000))
		size_display="${size_k}k"
	else
		size_display="${size}"
	fi

	tokens_display="${current_display}/${size_display} tokens"
else
	context_info="[░░░░░░░░░░] 0%"
	size=$(echo "$input" | jq '.context_window.context_window_size')
	if [ "$size" -ge 1000 ]; then
		size_k=$((size / 1000))
		size_display="${size_k}k"
	else
		size_display="${size}"
	fi
	tokens_display="0/${size_display} tokens"
fi

# Output
p
