#!/bin/bash
# Triggered by launchd when macOS appearance changes.
# Reloads SketchyBar and restarts borders to pick up new colors.

# launchd uses a minimal PATH — add Homebrew so sketchybar/borders are found
export PATH="/opt/homebrew/bin:$PATH"

# Reload SketchyBar (re-runs init.lua, which re-requires colors.lua)
sketchybar --reload

# Restart borders (bordersrc re-detects appearance on launch)
pkill -x borders
# Small delay to ensure borders process is fully stopped
sleep 0.5
sh -c "$HOME/dev/dotfiles/configs/rift/bordersrc" &
disown
