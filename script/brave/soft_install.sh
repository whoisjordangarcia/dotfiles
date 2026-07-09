#!/bin/bash
#===============================================================================
# soft_install.sh — shared Brave soft-install helper (sourced by per-platform
# setup.sh). No SCRIPT_DIR use so it never clobbers the caller's.
#
# Replays configs/brave/extensions.txt through Brave's "External Extensions"
# mechanism: each <id>.json points Brave at the Web Store CRX endpoint, so Brave
# installs it on next launch as a NORMAL, user-removable extension — no managed
# policy, no enforcement, no "managed by your organization". Regenerate the list
# from your live browser with `brave-sync`.
#
# ADDITIVE ONLY: writes a manifest for each listed id that isn't already present
# and never removes anything, so it can't wipe extensions you added by hand or
# from another profile. Delete any you don't want in-browser; the removal sticks.
#
# Usage: brave_soft_install <extensions_txt> <external_extensions_dir>
#===============================================================================

_BRAVE_CRX_UPDATE_URL="https://clients2.google.com/service/update2/crx"

brave_soft_install() {
	local ext_list="$1" ext_dir="$2"
	if [ ! -f "$ext_list" ]; then
		info "No $(basename "$ext_list") yet — run 'brave-sync' to create it. Skipping."
		return 0
	fi
	mkdir -p "$ext_dir"
	local added=0 kept=0 id line
	while IFS= read -r line; do
		id="${line%%#*}"          # strip trailing "# name" comment
		id="${id//[[:space:]]/}"  # and all whitespace
		[ -z "$id" ] && continue  # blank / comment-only line
		# Chrome-family extension IDs are exactly 32 lowercase letters a-p.
		# Refuse malformed entries so a typo cannot create files outside the
		# external-extension directory through a path such as "../../foo".
		if [[ ! "$id" =~ ^[a-p]{32}$ ]]; then
			warn "Skipping invalid Brave extension ID: $id"
			continue
		fi
		if [ -e "$ext_dir/$id.json" ]; then
			kept=$((kept + 1))
			continue
		fi
		printf '{"external_update_url":"%s"}\n' "$_BRAVE_CRX_UPDATE_URL" >"$ext_dir/$id.json"
		added=$((added + 1))
	done <"$ext_list"
	success "Brave extensions: $added added, $kept already present (removable; apply on next launch)."
}
