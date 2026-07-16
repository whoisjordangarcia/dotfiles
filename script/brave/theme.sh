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
source "$DIR/soft_install.sh"
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
	# A Web Store theme must be INSTALLED before activating it, or extensions.theme.id
	# points at nothing and Brave silently falls back to the default theme. Queue the
	# manifests here (not just in setup.sh) so `brave-theme` alone is sufficient.
	# They can't ride extensions.txt: brave-sync regenerates it and skips themes.
	theme_ids=$(python3 "$DIR/apply_themes.py" ids "$THEMES")
	if [ -n "$theme_ids" ]; then
		theme_list=$(mktemp)
		printf '%s\n' "$theme_ids" >"$theme_list"
		brave_soft_install "$theme_list" "$BRAVE_DIR/External Extensions"
		rm -f "$theme_list"
	fi
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
