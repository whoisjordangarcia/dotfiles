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

	# Handle both real files/dirs and broken symlinks
	if [ -e "$target" ] || [ -L "$target" ]; then
		# If target is a symlink, report where it points and validate match
		if [ -L "$target" ]; then
			local link_dest
			link_dest=$(readlink "$target")

			# Try to resolve to absolute paths for a more robust comparison
			local resolved_source="$source"
			local resolved_link="$link_dest"
			if command -v realpath >/dev/null 2>&1; then
				resolved_source=$(realpath "$source" 2>/dev/null || echo "$source")
				# readlink may return relative or absolute path
				if [[ "$link_dest" = /* ]]; then
					resolved_link=$(realpath -m "$link_dest" 2>/dev/null || echo "$link_dest")
				else
					resolved_link=$(realpath -m "$(dirname "$target")/$link_dest" 2>/dev/null || echo "$(dirname "$target")/$link_dest")
				fi
			fi

			# Exact match -> nothing to do
			if [ "$resolved_link" = "$resolved_source" ]; then
				info "Symlink already in place: $target → $link_dest"
				return
			fi

			# Broken or mismatched symlink
			local dest_path
			if [[ "$link_dest" = /* ]]; then
				dest_path="$link_dest"
			else
				dest_path="$(dirname "$target")/$link_dest"
			fi
			if [ ! -e "$dest_path" ]; then
				status "Existing symlink is broken: $target → $link_dest"
			else
				status "Existing symlink points elsewhere: $target → $link_dest (expected $source)"
			fi
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