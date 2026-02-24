#!/bin/bash
# Get the SSH destination from the child process of the given pane PID
pane_pid="$1"
child_pid=$(pgrep -P "$pane_pid" ssh 2>/dev/null | head -1)
[ -z "$child_pid" ] && child_pid=$(pgrep -P "$pane_pid" -f ssh 2>/dev/null | head -1)
[ -z "$child_pid" ] && exit 0
# Extract the last argument (the host) from the ssh command
ps -o args= -p "$child_pid" 2>/dev/null | awk '{print $NF}'
