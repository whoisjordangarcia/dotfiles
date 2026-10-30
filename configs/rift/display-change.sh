#!/bin/bash
# display-change.sh — debounced display hotplug handler for sketchybar
#
# When macOS connects/disconnects a display, it fires multiple events over ~1-2s
# as it negotiates resolution, refresh rate, and color space. This waits for that
# to settle, then reloads SketchyBar once so it sizes to the final menu bar.
#
# display_change also fires on display sleep/wake and screen lock, which leave the
# arrangement untouched, so the reload only runs when the display frames differ
# from the last one this script saw.
#
# rift isn't paused here: it preserves workspaces across display changes (0.6.8+).
# If windows flicker on hotplug, set virtual_workspaces.auto_assign_windows false
# before the sleep and true after it (`rift-cli execute config set`).
#
# Triggered by: SketchyBar's display_change event (via run_on_start subscription)

LOCK=/tmp/.rift_display_change_lock
STATE=/tmp/.rift_display_change_displays

# If a display-change handler is already running, let it handle things
[ -f "$LOCK" ] && exit 0
touch "$LOCK"

# Wait for macOS to finish display negotiation (~2s is conservative)
sleep 2

# Re-size SketchyBar to the (possibly different) main display's menu bar.
# Ask AppKit, not `sketchybar --query displays`: sketchybar caches frames until
# its next reload, so a resolution change would compare equal and never reload.
DISPLAYS=$(/usr/bin/osascript -l JavaScript -e 'ObjC.import("AppKit"); ObjC.unwrap($.NSScreen.screens).map(s => JSON.stringify(s.frame)).join("\n")' 2>/dev/null)
# Never save a blank answer, or the next event reloads for nothing.
if [ -z "$DISPLAYS" ]; then
    /opt/homebrew/bin/sketchybar --reload
elif [ "$DISPLAYS" != "$(cat "$STATE" 2>/dev/null)" ]; then
    printf '%s' "$DISPLAYS" > "$STATE"
    /opt/homebrew/bin/sketchybar --reload
fi

# Release lock
rm -f "$LOCK"
