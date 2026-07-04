#!/usr/bin/env bash
# Detect Claude Code state across all panes of a tmux session and render a
# statusline dot. Wired into status-left in .tmux.conf.
#
# Usage: claude_status.sh <session_id>
# Test hooks (pure, no tmux needed):
#   claude_status.sh --classify   # screen text on stdin → waiting|churning|idle
#   claude_status.sh --render <state>
#
# States (priority: high → low):
#   waiting  → amber filled dot (●) — Claude is blocked on a tool-approval
#                                     prompt, user input is required
#   churning → green filled dot (●) — Claude is actively processing (spinner)
#   idle     → dim hollow dot  (○) — Claude is alive, no active work
#   none     → blank                — no Claude process in this session
#
# "Alive" check is process-based: ps -t <tty> lists every process attached to
# the pane's TTY. This catches Claude whether it is actively processing, idle
# at a prompt, or paused — much more reliable than grepping spinner text.
#
# Screen checks look at the last 15 visible lines only (no scrollback) so
# stale "Do you want to..." text from past turns doesn't count.

# Classify a pane's visible screen (stdin) for a pane known to host Claude.
classify_screen() {
  local recent
  recent=$(tail -n 15)

  # Waiting wins (most actionable). Require the literal question text so we
  # don't false-match Claude's slash-command menu or option pickers.
  if grep -qE 'Do you want to (proceed|continue)\?' <<< "$recent"; then
    echo "waiting"
  elif grep -qE 'esc to interrupt|ctrl-t for thinking' <<< "$recent"; then
    echo "churning"
  else
    echo "idle"
  fi
}

# Map a state name to its tmux format-string rendering.
render_state() {
  case "$1" in
    waiting)  printf '#[fg=#fab387,bold]●#[default] ' ;;
    churning) printf '#[fg=#a6e3a1,bold]●#[default] ' ;;
    idle)     printf '#[fg=colour245]○#[default] ' ;;
    *)        printf '' ;;
  esac
}

# --- Test hooks -------------------------------------------------------------
case "${1:-}" in
  --classify) classify_screen; exit 0 ;;
  --render)   render_state "${2:-none}"; exit 0 ;;
esac

# --- Live detection ---------------------------------------------------------
session_id="${1:-}"
[[ -z "$session_id" ]] && exit 0

claude_on_tty() {
  local tty="${1#/dev/}"
  [[ -z "$tty" ]] && return 1
  ps -t "$tty" -o command= 2>/dev/null | grep -qE '(^|/)claude( |$)'
}

state="none"

while IFS=$'\t' read -r pane_id pane_tty; do
  claude_on_tty "$pane_tty" || continue

  # At minimum, Claude is alive → idle
  [[ "$state" == "none" ]] && state="idle"

  pane_state=$(tmux capture-pane -t "$pane_id" -p 2>/dev/null | classify_screen) || continue
  case "$pane_state" in
    waiting)  state="waiting"; break ;;                # most actionable — stop
    churning) state="churning" ;;                      # keep looking for waiting
  esac
done < <(tmux list-panes -s -t "$session_id" -F '#{pane_id}	#{pane_tty}' 2>/dev/null)

render_state "$state"
