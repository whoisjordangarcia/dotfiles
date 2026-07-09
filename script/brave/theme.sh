#!/bin/bash
#===============================================================================
# theme.sh — apply the soft, per-machine Brave config that can't ride the
# browser-wide External Extensions path: per-profile colors (Work vs Personal,
# so they're visually distinct) and brave://flags experiments. Both are written
# directly into Brave's own files, so it REFUSES while Brave is running (edits
# are overwritten on exit). Run as `brave-theme`.
#===============================================================================
set -euo pipefail

DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$DIR/../common/log.sh"
REPO_DIR=$(cd -- "$DIR/../.." &>/dev/null && pwd)

case "$OSTYPE" in
	darwin*) BRAVE_DIR="$HOME/Library/Application Support/BraveSoftware/Brave-Browser" ;;
	*) BRAVE_DIR="$HOME/.config/BraveSoftware/Brave-Browser" ;;
esac
THEMES="$REPO_DIR/configs/brave/profile-themes.txt"
FLAGS="$REPO_DIR/configs/brave/flags.txt"
PREFS="$REPO_DIR/configs/brave/prefs.txt"
EXT_LIST="$REPO_DIR/configs/brave/extensions.txt"

[ -d "$BRAVE_DIR" ] || { info "No Brave profile dir — skipping."; exit 0; }
if pgrep -x "Brave Browser" &>/dev/null || pgrep -x brave &>/dev/null || pgrep -x brave-browser &>/dev/null; then
	info "Brave is running — quit it first, then run 'brave-theme' (edits are overwritten while open)."
	exit 0
fi

if [ -f "$THEMES" ]; then
	python3 "$DIR/apply_themes.py" "$BRAVE_DIR" "$THEMES" | while read -r line; do step "$line"; done
fi
if [ -f "$FLAGS" ]; then
	python3 "$DIR/apply_flags.py" "$BRAVE_DIR" "$FLAGS" | while read -r line; do step "$line"; done
fi
if [ -f "$PREFS" ]; then
	python3 "$DIR/brave_prefs.py" apply "$BRAVE_DIR" "$PREFS" | while read -r line; do step "$line"; done
fi
# Pin the managed extensions (from extensions.txt) to the toolbar, all profiles.
if [ -f "$EXT_LIST" ]; then
	ids=()
	while IFS= read -r line; do
		id="${line%%#*}"; id="${id//[[:space:]]/}"
		[ -n "$id" ] && ids+=("$id")
	done <"$EXT_LIST"
	[ ${#ids[@]} -gt 0 ] && python3 "$DIR/brave_prefs.py" pin "$BRAVE_DIR" "${ids[@]}" | while read -r line; do step "$line"; done
fi
success "Applied per-profile colors + flags + prefs + pinned extensions. Relaunch Brave to see them."
