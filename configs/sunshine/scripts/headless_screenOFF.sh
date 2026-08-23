#!/bin/bash
# Panic / manual cleanup (SUPER+SHIFT+F3): tear down the ephemeral MOONLIGHT
# capture output if a stream's undo (screenON) ever fails to fire, plus any
# stray auto-named HEADLESS-* outputs. The persistent MAIN anchor is left
# intact so Sunshine's encoder probe always keeps a surface.
set -euo pipefail
source "$HOME/.config/sunshine/scripts/lib/sunshine_display.sh"
ensure_hyprland_env || exit 0

# Remove the named ephemeral capture output (no-op if absent).
restore_capture_display

# Sweep any leftover auto-named headless outputs. MAIN/MOONLIGHT are managed by
# name elsewhere and are never matched here.
hyprctl -j monitors all | jq -r '.[] | select(.name | test("^HEADLESS-")).name' \
	| while read -r mon; do
		[ -n "$mon" ] || continue
		hyprctl output remove "$mon" >/dev/null 2>&1 || true
	done
