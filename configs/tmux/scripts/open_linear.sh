#!/bin/bash
# Open the Linear issue for the current git branch in the browser
# Parses ticket ID from branch name (e.g. jordan/NES-1234-description → NES-1234)
# Args: $1 = pane_current_path

pane_path="${1:-$PWD}"

branch=$(git -C "$pane_path" branch --show-current 2>/dev/null)
if [ -z "$branch" ]; then
    osascript -e 'display notification "Not a git repository" with title "tmux: Open Linear"' 2>/dev/null
    exit 1
fi

ticket=$(echo "$branch" | grep -oE '[A-Z]+-[0-9]+' | head -1)
if [ -z "$ticket" ]; then
    msg="No ticket ID in branch: $branch"
    osascript -e "display notification \"$msg\" with title \"tmux: Open Linear\"" 2>/dev/null
    exit 1
fi

open "https://linear.app/nest/issue/$ticket"
