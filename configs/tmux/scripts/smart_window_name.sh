#!/bin/bash
# Smart window name: show contextual name based on path and command
# Usage: smart_window_name.sh <pane_current_path> <pane_current_command> <pane_pid>
path="$1"
cmd="$2"
pane_pid="$3"

# Known dev roots — add more as needed
DEV_ROOTS="$HOME/dev:$HOME/projects:$HOME/work:$HOME/src"

# Fast git repo name: use git rev-parse instead of walking directories
# Strips "jordan-" or "jordan/" prefix from worktree names
get_repo_name() {
    local repo_root
    repo_root=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) || return 1
    local name
    name=$(basename "$repo_root")
    name="${name#jordan-}"
    name="${name#jordan/}"
    echo "$name"
}

# Check if path is under a known dev root
is_dev_path() {
    IFS=':' read -ra roots <<< "$DEV_ROOTS"
    for root in "${roots[@]}"; do
        case "$1" in "$root"/*)
            return 0
            ;;
        esac
    done
    return 1
}

# Max window name length (truncated with ellipsis)
MAX_NAME_LEN=25

truncate_name() {
    local name="$1"
    if [ ${#name} -gt $MAX_NAME_LEN ]; then
        echo "${name:0:$((MAX_NAME_LEN - 1))}…"
    else
        echo "$name"
    fi
}

# Resolve generic "node" to the actual tool (nx, next, vite, etc.)
# Reads the direct child process args from the pane's shell
resolve_node_cmd() {
    local pid="$1"
    local child_pid
    child_pid=$(pgrep -P "$pid" 2>/dev/null | head -1)
    [ -z "$child_pid" ] && echo "node" && return

    local args
    args=$(ps -o args= -p "$child_pid" 2>/dev/null)

    case "$args" in
        *nx\ *)
            # Extract just the nx subcommand and target (e.g. "nx serve app")
            local nx_target
            nx_target=$(echo "$args" | sed -n 's/.*nx [^ ]* \([^ :]*\).*/\1/p')
            if [ -n "$nx_target" ]; then
                echo "nx:$nx_target"
            else
                echo "nx"
            fi ;;
        *next\ dev*|*next\ build*|*next\ start*|*next-server*) echo "next" ;;
        *vite*)       echo "vite" ;;
        *jest*)       echo "jest" ;;
        *tsc*)        echo "tsc" ;;
        *webpack*)    echo "webpack" ;;
        *eslint*)     echo "eslint" ;;
        *prettier*)   echo "prettier" ;;
        *ts-node*)    echo "ts-node" ;;
        *tsx\ *)      echo "tsx" ;;
        *turbo*)      echo "turbo" ;;
        *)            echo "node" ;;
    esac
}

# Detect Claude Code (tmux reports version number like "2.1.72" as process name)
is_claude_cmd() {
    case "$1" in
        claude|*claude*) return 0 ;;
        [0-9]*.[0-9]*.[0-9]*) return 0 ;;  # version string = Claude Code
    esac
    return 1
}

# For non-shell commands, show command + repo context
if [ "$cmd" != "zsh" ] && [ "$cmd" != "bash" ] && [ "$cmd" != "fish" ]; then
    # Resolve Claude version string to friendly name
    display_cmd="$cmd"
    if is_claude_cmd "$cmd"; then
        display_cmd="claude"
    elif [ "$cmd" = "node" ] && [ -n "$pane_pid" ]; then
        display_cmd=$(resolve_node_cmd "$pane_pid")
    fi

    repo=$(get_repo_name "$path")
    if [ -n "$repo" ] && is_dev_path "$path"; then
        truncate_name "$display_cmd:$repo"
    else
        truncate_name "$display_cmd"
    fi
    exit 0
fi

# Shell prompt: show repo name if in a dev directory, otherwise basename
if is_dev_path "$path"; then
    repo=$(get_repo_name "$path")
    if [ -n "$repo" ]; then
        truncate_name "$repo"
        exit 0
    fi
fi

# Fallback: directory basename
truncate_name "$(basename "$path")"
