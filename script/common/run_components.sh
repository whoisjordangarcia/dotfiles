#!/usr/bin/env bash
#
# run_components — runs each component's setup.sh as a child process.
#
# Running as child processes (instead of `source`) keeps each script's
# `set -euo pipefail`, traps, and variable changes contained to itself.
# Anything a component must see (DOT_*, WORK_ENV, DOT_SYMLINK_MODE) must be
# exported by the caller.

# Private var — this file is sourced, so don't clobber the caller's SCRIPT_DIR
_RUN_COMPONENTS_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$_RUN_COMPONENTS_DIR/log.sh"

run_components() {
	local component script_path
	for component in "$@"; do
		section "$component"
		script_path="$_RUN_COMPONENTS_DIR/../${component}/setup.sh"
		if [[ -f "$script_path" ]]; then
			bash "$script_path" || fail "Component '$component' failed"
		else
			warn "Script for $component does not exist."
		fi
	done
}
