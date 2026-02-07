#!/bin/bash
# Session picker with process status monitoring
# Shows what's running in each session for quick context

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

# Build session list with status
build_session_list() {
    local curr="$1"
    tmux list-sessions -F '#{session_name}' | while read -r session; do
        # Get detailed process info
        proc_info=$(get_process_status "$session")
        icon=$(echo "$proc_info" | cut -d'|' -f1)
        status=$(echo "$proc_info" | cut -d'|' -f2)

        windows=$(tmux list-windows -t "$session" 2>/dev/null | wc -l | tr -d ' ')

        # Mark current session
        if [ "$session" = "$curr" ]; then
            marker="▸"
        else
            marker=" "
        fi

        # Output: marker icon session (windows) [status]
        printf "%s %s %-30s %s win  [%s]\n" "$marker" "$icon" "$session" "$windows" "$status"
    done
}

# Export function for fzf reload
export -f get_process_status
export -f build_session_list

# Run fzf and get selection
selected=$(build_session_list "$current_session" | fzf \
    --ansi \
    --header "Sessions (▸ = current)  │  Enter: switch  │  Ctrl-r: refresh" \
    --preview 'session=$(echo {} | awk "{print \$3}"); echo "═══ Windows ═══"; tmux list-windows -t "$session" -F "  #{window_index}: #{window_name} (#{pane_current_command})" 2>/dev/null; echo ""; echo "═══ Preview ═══"; tmux capture-pane -t "$session" -p 2>/dev/null | head -25' \
    --preview-window=right:50%:wrap \
    --bind "ctrl-r:reload(bash -c 'source ~/.tmux/scripts/session_picker.sh; build_session_list \"$current_session\"' 2>/dev/null || echo 'reload...')" \
    --pointer="▶" \
    --prompt="  " \
    --color="header:italic:dim,pointer:magenta,prompt:cyan")

# Output selected session name - tmux binding will handle the switch
if [ -n "$selected" ]; then
    session_name=$(echo "$selected" | awk '{print $3}')
    echo "$session_name"
fi
