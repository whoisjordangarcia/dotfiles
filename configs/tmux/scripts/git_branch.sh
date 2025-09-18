#!/bin/bash

# Git branch detection script for tmux statusline
# Works on any platform with git installed

get_git_branch() {
    local current_path="${1:-$(pwd)}"

    if command -v git >/dev/null 2>&1; then
        git -C "$current_path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# If called directly, get branch for current directory
# If called from tmux, it will pass the pane's current path
get_git_branch "$1"