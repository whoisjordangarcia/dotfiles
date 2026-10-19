#!/bin/bash
# display-change.sh — debounced display hotplug handler for sketchybar
#
# When macOS connects/disconnects a display, it fires multiple events over ~1-2s
# as it negotiates resolution, refresh rate, and color space. This waits for that
# to settle, then reloads SketchyBar once so it sizes to the final menu bar.
#
# rift isn't paused here: it preserves workspaces across display changes (0.6.8+).
# If windows flicker on hotplug, set virtual_workspaces.auto_assign_windows false
# before the sleep and true after it (`rift-cli execute config set`).
#
# Triggered by: SketchyBar's display_change event (via run_on_start subscription)

LOCK=/tmp/.rift_display_change_lock

# If a display-change handler is already running, let it handle things
[ -f "$LOCK" ] && exit 0
touch "$LOCK"

# Wait for macOS to finish display negotiation (~2s is conservative)
sleep 2

# Re-size SketchyBar to the (possibly different) main display's menu bar.
/opt/homebrew/bin/sketchybar --reload

# Release lock
rm -f "$LOCK"
