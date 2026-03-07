#!/bin/bash
# display-change.sh — debounced display hotplug handler for rift
#
# When macOS connects/disconnects a display, it fires multiple events over ~1-2s
# as it negotiates resolution, refresh rate, and color space. Rift's auto_assign_windows
# reacts to each sub-event, causing a "flicker storm" as windows get repositioned
# multiple times.
#
# This script debounces display changes by temporarily disabling auto_assign_windows,
# waiting for macOS to settle, then re-enabling it so Rift does a single clean re-tile.
#
# Triggered by: SketchyBar's display_change event (via run_on_start subscription)

LOCK=/tmp/.rift_display_change_lock

# If a display-change handler is already running, let it handle things
[ -f "$LOCK" ] && exit 0
touch "$LOCK"

# Immediately pause auto-assign to prevent flicker during negotiation
rift-cli execute config set --key virtual_workspaces.auto_assign_windows --value false 2>/dev/null

# Wait for macOS to finish display negotiation (~2s is conservative)
sleep 2

# Re-enable auto-assign — Rift performs a single clean workspace reassignment
rift-cli execute config set --key virtual_workspaces.auto_assign_windows --value true 2>/dev/null

# Release lock
rm -f "$LOCK"
