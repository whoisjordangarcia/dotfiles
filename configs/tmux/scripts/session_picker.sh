#!/bin/bash
# Session picker with process status monitoring
# Shows what's running in each session for quick context
# Enhanced: git branch, session age, multi-window process scanning

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

# Current session passed from tmux binding (more reliable in popups)
current_session="${1:-$(tmux display-message -p '#{session_name}')}"

# Get detailed process info - looks at actual command args, not just process name
get_process_status() {
    local session="$1"
    local pane_pid cmd_name full_cmd icon status

    # Get the pane's shell PID
    pane_pid=$(tmux display-message -t "$session" -p '#{pane_pid}' 2>/dev/null)
    [ -z "$pane_pid" ] && echo "  |unknown" && return

    # Get the foreground process name
    cmd_name=$(tmux display-message -t "$session" -p '#{pane_current_command}' 2>/dev/null)

    # For node/python, look at the actual command being run
    if [[ "$cmd_name" =~ ^(node|python|python3)$ ]]; then
        # Get child process and its full command line
        child_pid=$(pgrep -P "$pane_pid" 2>/dev/null | head -1)
        if [ -n "$child_pid" ]; then
            full_cmd=$(ps -p "$child_pid" -o args= 2>/dev/null | head -1)

            # Detect specific tools from command args
            case "$full_cmd" in
                *"nx serve"*|*"nx run"*serve*)
                    icon="🚀"; status="nx serve"
                    ;;
                *"nx build"*|*"nx run"*build*)
                    icon="📦"; status="nx build"
                    ;;
                *"nx test"*|*"nx run"*test*)
                    icon="󰙨 "; status="nx test"
                    ;;
                *"nx "*|*"/nx "*)
                    icon="▲ "; status="nx"
                    ;;
                *"next dev"*|*"next-server"*)
                    icon="▲ "; status="next dev"
                    ;;
                *"next build"*)
                    icon="▲ "; status="next build"
                    ;;
                *"vite"*)
                    icon="⚡"; status="vite"
                    ;;
                *"webpack"*)
                    icon="📦"; status="webpack"
                    ;;
                *"jest"*|*"vitest"*)
                    icon="󰙨 "; status="testing"
                    ;;
                *"eslint"*|*"prettier"*)
                    icon="✨"; status="linting"
                    ;;
                *"tsc"*|*"typescript"*)
                    icon="󰛦 "; status="tsc"
                    ;;
                *"claude"*)
                    icon="🤖"; status="claude"
                    ;;
                *)
                    # Fall back to generic node/python
                    if [[ "$cmd_name" == "node" ]]; then
                        icon="󰎙 "; status="node"
                    else
                        icon=" "; status="python"
                    fi
                    ;;
            esac
            echo "$icon|$status"
            return
        fi
    fi

    # Default detection for other commands
    case "$cmd_name" in
        claude*)
            icon="🤖"; status="claude"
            ;;
        nvim|vim|vi)
            icon=" "; status="editing"
            ;;
        cargo|rustc)
            icon="🦀"; status="rust"
            ;;
        go)
            icon=" "; status="go"
            ;;
        docker|docker-compose)
            icon="🐳"; status="docker"
            ;;
        git)
            icon=" "; status="git"
            ;;
        ssh|mosh)
            icon="󰣀 "; status="remote"
            ;;
        make|cmake|ninja)
            icon="⚙ "; status="building"
            ;;
        pytest|jest|vitest|rspec)
            icon="󰙨 "; status="testing"
            ;;
        zsh|bash|fish)
            icon="  "; status="idle"
            ;;
        node|npm|pnpm|yarn|bun)
            icon="󰎙 "; status="$cmd_name"
            ;;
        python|python3)
            icon=" "; status="python"
            ;;
        *)
            icon="  "; status="$cmd_name"
            ;;
    esac
    echo "$icon|$status"
}

# Collect all active processes across all windows in a session
get_all_window_statuses() {
    local session="$1"
    local statuses=()
    local seen=()

    while read -r win_idx; do
        local info
        info=$(get_process_status "$session:@${win_idx}")
        local st
        st=$(echo "$info" | cut -d'|' -f2)

        # Skip idle/unknown, deduplicate
        if [[ "$st" != "idle" && "$st" != "unknown" && "$st" != "zsh" && "$st" != "bash" ]]; then
            local already=false
            for s in "${seen[@]}"; do
                [[ "$s" == "$st" ]] && already=true && break
            done
            if [[ "$already" == false ]]; then
                seen+=("$st")
                statuses+=("$st")
            fi
        fi
    done < <(tmux list-windows -t "$session" -F '#{window_index}' 2>/dev/null)

    if [ ${#statuses[@]} -gt 0 ]; then
        local IFS=', '
        echo "${statuses[*]}"
    else
        echo "idle"
    fi
}

# Human-readable session age
format_age() {
    local created="$1"
    local now
    now=$(date +%s)
    local age_secs=$((now - created))

    if [ $age_secs -gt 86400 ]; then
        echo "$((age_secs / 86400))d"
    elif [ $age_secs -gt 3600 ]; then
        echo "$((age_secs / 3600))h"
    else
        echo "$((age_secs / 60))m"
    fi
}

# Build session list with status
# Format uses ‖ as delimiter for reliable parsing: marker‖icon‖session‖display_text
build_session_list() {
    local curr="$1"
    tmux list-sessions -F '#{session_name}|#{session_created}' | while IFS='|' read -r session created; do
        # Get process info from the active pane (for the icon)
        proc_info=$(get_process_status "$session")
        icon=$(echo "$proc_info" | cut -d'|' -f1)

        # Scan all windows for a combined status
        all_statuses=$(get_all_window_statuses "$session")

        windows=$(tmux list-windows -t "$session" 2>/dev/null | wc -l | tr -d ' ')

        # Git branch from the active pane's directory
        pane_path=$(tmux display-message -t "$session" -p '#{pane_current_path}' 2>/dev/null)
        git_branch=$(git -C "$pane_path" branch --show-current 2>/dev/null)
        if [ -n "$git_branch" ]; then
            location=" $git_branch"
        else
            location=$(basename "$pane_path" 2>/dev/null)
        fi

        # Session age
        age=$(format_age "$created")

        # Mark current session
        if [ "$session" = "$curr" ]; then
            marker="▸"
        else
            marker=" "
        fi

        # Use ‖ as hidden delimiter between session name and display info
        printf "%s %s ‖%s‖ %sw  %-18s %4s  [%s]\n" "$marker" "$icon" "$session" "$windows" "$location" "$age" "$all_statuses"
    done
}

# Generate preview for a session (called by fzf --preview)
show_preview() {
    local session="$1"
    [ -z "$session" ] && return

    local pane_path git_branch created attached

    pane_path=$(tmux display-message -t "$session" -p '#{pane_current_path}' 2>/dev/null)
    git_branch=$(git -C "$pane_path" branch --show-current 2>/dev/null)
    created=$(tmux display-message -t "$session" -p '#{session_created_string}' 2>/dev/null)
    attached=$(tmux display-message -t "$session" -p '#{session_attached}' 2>/dev/null)

    echo "╭─── $session ───"
    [ -n "$pane_path" ] && echo "│  $pane_path"
    [ -n "$git_branch" ] && echo "│  $git_branch"
    [ -n "$created" ] && echo "│ 󰃰 $created"
    [ "$attached" -gt 0 ] 2>/dev/null && echo "│ ⚡ Attached ($attached client(s))"
    echo "╰───────────────────────"
    echo ""
    echo "══ Windows ══"
    tmux list-windows -t "$session" -F "  #{?window_active,▸, } #{window_index}: #{window_name} (#{pane_current_command})#{?window_zoomed_flag, 󰊓,}" 2>/dev/null
    echo ""
    echo "══ Preview ══"
    tmux capture-pane -t "$session" -p 2>/dev/null | tail -20
}

# Allow this script to be called in preview mode
if [ "$2" = "--preview" ]; then
    show_preview "$3"
    exit 0
fi

# Export functions for fzf reload
export -f get_process_status
export -f get_all_window_statuses
export -f format_age
export -f build_session_list

SELF_SCRIPT="$HOME/.tmux/scripts/session_picker.sh"

# Run fzf and get selection
selected=$(build_session_list "$current_session" | fzf \
    --ansi \
    --header "Sessions (▸ = current)  │  Enter: switch  │  ^r: refresh  │  ^x: kill" \
    --delimiter '‖' \
    --preview "bash \"$SELF_SCRIPT\" _ --preview {2}" \
    --preview-window=right:50%:wrap \
    --bind "ctrl-r:reload(bash -c 'source \"$SELF_SCRIPT\"; build_session_list \"$current_session\"' 2>/dev/null || echo 'reload...')" \
    --bind "ctrl-x:execute-silent(session={2}; session=\$(echo \"\$session\" | xargs); tmux kill-session -t \"\$session\" 2>/dev/null)+reload(bash -c 'source \"$SELF_SCRIPT\"; build_session_list \"$current_session\"' 2>/dev/null || echo 'reload...')" \
    --pointer="▶" \
    --prompt="  " \
    --color="header:italic:dim,pointer:magenta,prompt:cyan")

# Extract session name from between ‖ delimiters
if [ -n "$selected" ]; then
    session_name=$(echo "$selected" | sed 's/.*‖\(.*\)‖.*/\1/' | xargs)
    echo "$session_name"
fi
