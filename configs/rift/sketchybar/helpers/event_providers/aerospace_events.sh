#!/usr/bin/env bash
# Lightweight poller to emit custom SketchyBar events based on Aerospace state.
# Emits:
#  - aerospace_workspace_change: when focused workspace changes
#  - aerospace_focus_change: when front window focus (app) changes
#
# The script keeps minimal state and only triggers events when the value changes.
# Interval can be adjusted via AEROSPACE_POLL_INTERVAL (defaults to 1 second)

set -euo pipefail

INTERVAL="${AEROSPACE_POLL_INTERVAL:-1}"

last_workspace=""
last_focus_app=""

# Utility: safely run aerospace commands, ignore errors (e.g., during reload)
a() { aerospace "$@" 2>/dev/null || true; }

while true; do
  current_workspace="$(a list-workspaces --focused 2>/dev/null | tr -d '\n' | xargs)"
  # Fallback to blank if nothing
  current_workspace="${current_workspace:-}" 

  # Front app (use macOS API via aerospace list-windows focused, else AppleScript fallback)
  current_focus_app="$(a list-windows --focused --format '%{app-name}' 2>/dev/null | tr -d '\n' | xargs)"

  if [[ -n "$current_workspace" && "$current_workspace" != "$last_workspace" ]]; then
    sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE="$current_workspace"
    last_workspace="$current_workspace"
  fi

  if [[ "$current_focus_app" != "$last_focus_app" ]]; then
    # We only need to broadcast that some focus-related thing changed.
    sketchybar --trigger aerospace_focus_change FOCUSED_APP="$current_focus_app"
    last_focus_app="$current_focus_app"
  fi

  sleep "$INTERVAL"

done
