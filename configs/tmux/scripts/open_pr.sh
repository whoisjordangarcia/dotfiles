#!/bin/bash
# Open the GitHub PR for the current branch in the browser
# Args: $1 = pane_current_path

pane_path="${1:-$PWD}"

git_root=$(git -C "$pane_path" rev-parse --show-toplevel 2>/dev/null)
if [ -z "$git_root" ]; then
    osascript -e 'display notification "Not a git repository" with title "tmux: Open PR"' 2>/dev/null
    exit 1
fi

cd "$git_root" || exit 1

output=$(gh pr view --web 2>&1)
if [ $? -ne 0 ]; then
    # Sanitize for osascript
    msg=$(echo "$output" | head -1 | tr '"' "'")
    osascript -e "display notification \"$msg\" with title \"tmux: Open PR\"" 2>/dev/null
fi
