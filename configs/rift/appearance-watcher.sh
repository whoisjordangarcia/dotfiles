#!/bin/bash
# Triggered by launchd when macOS appearance changes.
# Reloads SketchyBar and restarts borders to pick up new colors.

# launchd uses a minimal PATH — add Homebrew so sketchybar/borders are found
export PATH="/opt/homebrew/bin:$PATH"

# Debounce: .GlobalPreferences.plist is written multiple times per appearance
# change, so WatchPaths fires multiple times. Skip if we ran within 5 seconds.
LOCK="/tmp/appearance-watcher.lock"
NOW=$(date +%s)
if [ -f "$LOCK" ]; then
    LAST=$(cat "$LOCK" 2>/dev/null || echo 0)
    if [ $((NOW - LAST)) -lt 5 ]; then
        exit 0
    fi
fi
echo "$NOW" > "$LOCK"

# Reload SketchyBar (re-runs init.lua, which re-requires colors.lua)
sketchybar --reload

# Restart borders (bordersrc re-detects appearance on launch)
pkill -x borders
sleep 0.5
# Double-fork via perl so borders is reparented to PID 1 and survives
# launchd cleaning up this job's process group
perl -e 'use POSIX; fork and exit; POSIX::setsid(); exec @ARGV' -- \
    bash -c "export PATH=/opt/homebrew/bin:\$PATH; $HOME/dev/dotfiles/configs/rift/bordersrc"
