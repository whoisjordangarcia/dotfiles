#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/log.sh"

link_file() {
	local source="$1"
	local target="$2"

	if [ -e "$target" ]; then
		user "File $target exists. [O]verride/[B]ackup/[S]kip?"
		read -r choice
		case "$choice" in
		[Oo])
			rm -rf "$target" && ln -s "$source" "$target"
			info "Overridden."
			;;
		[Bb])
			# Get current date in YYYYMMDD format
			DATE_SUFFIX=$(date +%Y%m%d)
			mv "$target" "${target}_$DATE_SUFFIX.bak" && ln -s "$source" "$target"
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
