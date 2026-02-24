#!/bin/bash
# Smart window name: show git repo name, or directory basename
# Usage: smart_window_name.sh <pane_current_path> <pane_current_command>
path="$1"
cmd="$2"

# If not in a shell, show the command name
if [ "$cmd" != "zsh" ] && [ "$cmd" != "bash" ]; then
    echo "$cmd"
    exit 0
fi

# Walk up to find .git directory
dir="$path"
while [ "$dir" != "/" ]; do
    if [ -d "$dir/.git" ]; then
        basename "$dir"
        exit 0
    fi
    dir=$(dirname "$dir")
done

# No git repo found, show directory basename
basename "$path"
