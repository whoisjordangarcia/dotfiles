#!/bin/bash
# Worktree dev server dashboard
# Shows listening ports whose processes are running under the current git worktree
# Args: $1 = pane_current_path

pane_path="${1:-$PWD}"

# ANSI colors (work inside tmux display-popup)
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RESET='\033[0m'

wt_path=$(git -C "$pane_path" rev-parse --show-toplevel 2>/dev/null)
if [ -z "$wt_path" ]; then
    echo "Not in a git repository"
    echo ""
    echo "Press any key to close..."
    read -r -n 1
    exit 1
fi

branch=$(git -C "$pane_path" branch --show-current 2>/dev/null)

echo ""
echo -e "  ${BOLD}Dev Server Dashboard${RESET}"
echo -e "  ${DIM}${wt_path}${RESET}  ${CYAN}(${branch})${RESET}"
echo -e "  ────────────────────────────────────────"
echo ""

found=0
declare -A seen_ports

# Get all listening TCP ports
while IFS= read -r line; do
    [ -z "$line" ] && continue

    pid=$(echo "$line" | awk '{print $2}')
    proc=$(echo "$line" | awk '{print $1}')
    addr=$(echo "$line" | awk '{print $9}')
    port=$(echo "$addr" | grep -oE '[0-9]+$')

    [ -z "$port" ] && continue
    [ -n "${seen_ports[$port]}" ] && continue

    # Check if this process's working dir is under our worktree
    proc_cwd=$(lsof -p "$pid" -a -d cwd -Fn 2>/dev/null | grep '^n' | head -1 | sed 's/^n//')

    if [[ "$proc_cwd" == "$wt_path"* ]]; then
        seen_ports[$port]=1
        echo -e "  ${GREEN}●${RESET}  ${BOLD}http://localhost:${port}${RESET}  ${DIM}(${proc}, pid ${pid})${RESET}"
        found=1
    fi
done < <(lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | tail -n +2)

if [ "$found" -eq 0 ]; then
    echo -e "  ${YELLOW}No dev servers found for this worktree${RESET}"
    echo ""
    echo -e "  ${DIM}All listening ports:${RESET}"
    lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | tail -n +2 | \
        awk '{print $1, $2, $9}' | sort -u -k3 | \
        while read proc pid addr; do
            port=$(echo "$addr" | grep -oE '[0-9]+$')
            [ -n "$port" ] && echo -e "  ${DIM}○  localhost:${port}  (${proc})${RESET}"
        done | head -10
fi

echo ""
echo -e "  ${DIM}Press any key to close...${RESET}"
read -r -n 1
