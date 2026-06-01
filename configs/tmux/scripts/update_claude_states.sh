#!/usr/bin/env bash
# Pre-compute Claude Code state for every tmux session and store it as the
# `@claude_state` user option on each session. Designed to be run by a tmux
# key binding immediately before `choose-tree` so the chooser format can
# read `#{@claude_state}` directly.
#
# Three-state model (priority: high → low):
#   waiting  → amber filled dot (●) — Claude is blocked on a tool-approval
#                                     prompt, user input is required
#   churning → green filled dot (●) — Claude is actively processing (spinner)
#   idle     → dim hollow dot  (○) — Claude is alive, no active work
#   none     → blank pad           — no Claude process in this session

set -u

claude_on_tty() {
  local tty="${1#/dev/}"
  [[ -z "$tty" ]] && return 1
  ps -t "$tty" -o command= 2>/dev/null | grep -qE '(^|/)claude( |$)'
}

while IFS=$'\t' read -r sid; do
  state="none"

  while IFS=$'\t' read -r pane_id pane_tty; do
    claude_on_tty "$pane_tty" || continue

    # At minimum: Claude is alive in this pane → idle
    [[ "$state" == "none" ]] && state="idle"

    # Visible-screen-only check (no scrollback) — past-turn text doesn't count
    screen=$(tmux capture-pane -t "$pane_id" -p 2>/dev/null) || continue
    recent=$(tail -n 15 <<< "$screen")

    # Waiting wins (most actionable). Require the literal question text so we
    # don't false-match Claude's slash-command menu or option pickers.
    if grep -qE 'Do you want to (proceed|continue)\?' <<< "$recent"; then
      state="waiting"
      break
    fi

    # Churning — spinner footer is visible right now
    if grep -qE 'esc to interrupt|ctrl-t for thinking' <<< "$recent"; then
      state="churning"
      # don't break; a later pane could still upgrade to waiting
    fi
  done < <(tmux list-panes -s -t "$sid" -F '#{pane_id}	#{pane_tty}' 2>/dev/null)

  # Store the state name as plain text — styling is applied by the tmux
  # format string at render time. Avoids `#` parsing issues with hex colors
  # embedded in option values.
  tmux set-option -t "$sid" @claude_state "$state"
done < <(tmux list-sessions -F '#{session_id}')
