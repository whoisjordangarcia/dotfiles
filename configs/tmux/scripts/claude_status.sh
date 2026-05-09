#!/usr/bin/env bash
# Detect Claude Code state across all panes of a tmux session.
# Usage: claude_status.sh <session_id>
# States (priority order):
#   waiting → Claude is waiting for user approval  (amber dot, needs attention)
#   working → Claude process is alive in a pane    (green dot, ambient marker)
#   none    → no Claude in this session            (blank, preserves alignment)
#
# "Alive" check is process-based: ps -t <tty> lists every process attached to
# the pane's TTY. This catches Claude whether it is actively processing, idle
# at a prompt, or paused — much more reliable than grepping spinner text.
#
# Waiting check is visible-screen only (no scrollback) to avoid matching
# stale "Do you want to..." text from past turns.

session_id="${1:-}"
[[ -z "$session_id" ]] && { printf '  '; exit 0; }

state="none"

claude_on_tty() {
  local tty="${1#/dev/}"
  [[ -z "$tty" ]] && return 1
  ps -t "$tty" -o command= 2>/dev/null | grep -qE '(^|/)claude( |$)'
}

while IFS=$'\t' read -r pane_id pane_tty; do
  claude_on_tty "$pane_tty" || continue

  # At minimum, Claude is alive → working
  [[ "$state" == "none" ]] && state="working"

  # Upgrade to "waiting" if an approval prompt is on screen right now.
  # Anchored patterns minimise false positives from chat content.
  screen=$(tmux capture-pane -t "$pane_id" -p 2>/dev/null) || continue
  if grep -qE '^❯ [0-9]\. |Do you want to (proceed|continue)\?' <<< "$screen"; then
    state="waiting"
    break
  fi
done < <(tmux list-panes -s -t "$session_id" -F '#{pane_id}	#{pane_tty}' 2>/dev/null)

case "$state" in
  working) printf '#[fg=#a6e3a1,bold]●#[default] ' ;;
  waiting) printf '#[fg=#fab387,bold]●#[default] ' ;;
  *)       printf '  ' ;;
esac
