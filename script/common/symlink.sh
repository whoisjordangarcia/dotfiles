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

	# Handle both real files/dirs and symlinks (including broken)
	if [ -e "$target" ] || [ -L "$target" ]; then
		local resolved_source="$source"
		local resolved_target="$target"
		if command -v realpath >/dev/null 2>&1; then
			resolved_source=$(realpath -m "$source" 2>/dev/null || echo "$source")
			resolved_target=$(realpath -m "$target" 2>/dev/null || echo "$target")
		fi

		if [[ "$resolved_source" == "$resolved_target" ]]; then
			info "Source and target are the same. Skipping: $target"
			return
		fi

		# If target is a symlink, validate and skip without prompting
		if [ -L "$target" ]; then
			local link_dest
			link_dest=$(readlink "$target")

			# Resolve to absolute paths when possible for comparison
			local resolved_source="$source"
			local resolved_link="$link_dest"
			if command -v realpath >/dev/null 2>&1; then
				resolved_source=$(realpath "$source" 2>/dev/null || echo "$source")
				if [[ "$link_dest" = /* ]]; then
					resolved_link=$(realpath -m "$link_dest" 2>/dev/null || echo "$link_dest")
				else
					resolved_link=$(realpath -m "$(dirname "$target")/$link_dest" 2>/dev/null || echo "$(dirname "$target")/$link_dest")
				fi
			fi

			if [ "$resolved_link" = "$resolved_source" ]; then
				info "Symlink already in place: $target → $link_dest"
			else
				info "Existing symlink detected; skipping: $target → $link_dest"
			fi
			return
		fi

		# Non-symlink exists: prompt user
		user "The $type '$target' already exists. [O]verride/[B]ackup/[S]kip?"
		read -r choice
		case "$choice" in
		[Oo])
			rm -rf "$target" && ln -s "$source" "$target"
			info "Overridden."
			;;
		[Bb])
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
