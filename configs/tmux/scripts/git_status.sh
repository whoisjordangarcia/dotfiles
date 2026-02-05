#!/bin/bash

# Enhanced git status script for tmux statusline
# Shows branch with worktree indicator and dirty status

ICON_LEAF=$(printf '\xef\x81\xac')  # U+F06C nf-fa-leaf

get_git_status() {
    local current_path="${1:-$(pwd)}"

    # Check if in a git repo
    if ! git -C "$current_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo ""
        return
    fi

    # Get branch name
    local branch
    branch=$(git -C "$current_path" rev-parse --abbrev-ref HEAD 2>/dev/null)

    if [ -z "$branch" ]; then
        echo ""
        return
    fi

    # Truncate long branch names (keep first 20 chars)
    if [ ${#branch} -gt 20 ]; then
        branch="${branch:0:18}.."
    fi

    # Check if in a worktree
    local worktree_indicator=""
    if [[ "$current_path" == *".worktrees"* ]]; then
        worktree_indicator="$ICON_LEAF"
    fi

    # Check for uncommitted changes (dirty status)
    local dirty=""
    if ! git -C "$current_path" diff --quiet 2>/dev/null || \
       ! git -C "$current_path" diff --cached --quiet 2>/dev/null; then
        dirty="*"
    fi

    # Check for untracked files
    if [ -n "$(git -C "$current_path" ls-files --others --exclude-standard 2>/dev/null | head -1)" ]; then
        dirty="${dirty}+"
    fi

    echo "${worktree_indicator} ${branch}${dirty}"
}

get_git_status "$1"
