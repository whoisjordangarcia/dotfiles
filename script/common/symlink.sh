#!/usr/bin/env bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/log.sh"

link_file() {
	local source="$1"
	local target="$2"
	local type="file" # Default to file
	if [ -d "$source" ]; then
		type="directory"
	fi

	if [ -e "$target" ]; then
		# Check if target is already a symlink pointing to the correct source
		if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
			info "Symlink already exists and points to correct source. Skipping."
			return
		fi

		# Add some verbosity to the prompt
		user "The $type '$target' already exists. [O]verride/[B]ackup/[S]kip?"
		read -r choice
		case "$choice" in
		[Oo])
			rm -rf "$target" && ln -s "$source" "$target"
			info "Overridden."
			;;
		[Bb])
			# Get current date in YYYYMMDD format
			DATE_SUFFIX=$(date +%Y%m%d)
			mv "$target" "${target}_${DATE_SUFFIX}.bak" && ln -s "$source" "$target"
			info "Backed up and linked."
			;;
		*)
			info "Skipped."
			;;
		esac
	else
		ln -s "$source" "$target"
		success "Created new Symlink $source -> $target."
	fi
}
