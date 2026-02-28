#!/bin/bash
# Permission Request Notification Hook for Claude Code
# Sends a macOS notification when Claude requests permission
# Uses a more alerting sound when the session contains "ralph"

set -eo pipefail

# Get current tmux session name, fallback to 'terminal' if not in tmux
SESSION=$(tmux display-message -p '#S' 2>/dev/null || echo 'terminal')

# Extract detailed permission information from the hook arguments
# $ARGUMENTS is provided by Claude Code and contains JSON with tool call details
# Default to empty JSON if not provided (for manual testing)
ARGUMENTS="${ARGUMENTS:-{}}"
TOOL=$(echo "$ARGUMENTS" | jq -r '.tool // "Unknown"' 2>/dev/null || echo 'Unknown')

# Build detailed message based on tool type
if [[ "$TOOL" == "Bash" ]]; then
  COMMAND=$(echo "$ARGUMENTS" | jq -r '.parameters.command // "unknown command"' 2>/dev/null | head -c 200)
  MESSAGE="Command: $COMMAND"
elif [[ "$TOOL" == "Read" ]]; then
  FILE=$(echo "$ARGUMENTS" | jq -r '.parameters.file_path // "unknown file"' 2>/dev/null | head -c 200)
  MESSAGE="Read: $FILE"
elif [[ "$TOOL" == "Write" ]] || [[ "$TOOL" == "Edit" ]]; then
  FILE=$(echo "$ARGUMENTS" | jq -r '.parameters.file_path // "unknown file"' 2>/dev/null | head -c 200)
  MESSAGE="$TOOL: $FILE"
elif [[ "$TOOL" == "WebFetch" ]]; then
  URL=$(echo "$ARGUMENTS" | jq -r '.parameters.url // "unknown url"' 2>/dev/null | head -c 200)
  MESSAGE="Fetch: $URL"
else
  # Fallback for other tools
  MESSAGE=$(echo "$ARGUMENTS" | jq -r '
    .parameters.command //
    .parameters.file_path //
    .parameters.url //
    .parameters.pattern //
    "operation"
  ' 2>/dev/null | head -c 200 || echo 'operation')
fi

# Choose sound based on session name
# Use longer, more alerting sound for ralph-related sessions
if echo "$SESSION" | grep -qi 'ralph'; then
  SOUND='Funk'    # Longer, more dramatic alert for Ralph
else
  SOUND='Glass'   # Subtle notification sound
fi

# Send notification using terminal-notifier
# Use -sender to show Ghostty icon instead of Terminal
terminal-notifier \
  -title "🤖 [$SESSION] $TOOL" \
  -subtitle 'Permission Required' \
  -message "$MESSAGE" \
  -sound "$SOUND" \
  -sender com.mitchellh.ghostty
