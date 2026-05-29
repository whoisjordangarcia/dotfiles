#!/bin/bash
# Get SSH destination in user@host format from the pane's ssh child process
pane_pid="$1"

find_ssh_pid() {
    local pid="$1"
    # Direct child named ssh
    local child
    child=$(pgrep -P "$pid" ssh 2>/dev/null | head -1)
    [ -n "$child" ] && echo "$child" && return
    # Full command path match (e.g. /usr/bin/ssh)
    pgrep -P "$pid" -f "ssh " 2>/dev/null | head -1
}

child_pid=$(find_ssh_pid "$pane_pid")
[ -z "$child_pid" ] && exit 0

ssh_args=$(ps -o args= -p "$child_pid" 2>/dev/null)
[ -z "$ssh_args" ] && exit 0

# Parse ssh args to extract user and host
# Handles: ssh user@host, ssh -l user host, ssh host
user=""
host=""
prev_arg=""

for arg in $ssh_args; do
    # Skip the ssh binary itself
    [ "$arg" = "ssh" ] || [[ "$arg" == */ssh ]] && { prev_arg="$arg"; continue; }

    if [ "$prev_arg" = "-l" ]; then
        user="$arg"
    elif [[ "$arg" != -* ]]; then
        # First non-option arg is the destination (skip option values)
        if [[ "$prev_arg" =~ ^-[bcDEeFIiJLmopQRSwX]$ ]]; then
            : # prev was an option that consumes this arg as its value
        elif [ -z "$host" ]; then
            if [[ "$arg" == *@* ]]; then
                user="${arg%%@*}"
                host="${arg#*@}"
            else
                host="$arg"
            fi
        fi
    fi
    prev_arg="$arg"
done

[ -z "$host" ] && exit 0
# printf '%s' (no trailing newline): a newline in a tmux #() status segment renders
# as an extra status row on terminals that don't collapse it.
[ -n "$user" ] && printf '%s' "${user}@${host}" || printf '%s' "$host"
