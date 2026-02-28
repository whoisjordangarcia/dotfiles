#!/usr/bin/env bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/log.sh"

# Resolve a path from a git worktree to the equivalent path in the main repo.
# Prevents symlinks from pointing into worktrees that may be deleted later.
_resolve_to_main_worktree() {
	local abs_path
	abs_path=$(realpath "$1" 2>/dev/null || echo "$1")

	local dir="$(dirname "$abs_path")"
	local git_toplevel git_common_dir main_root

	git_toplevel=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || { echo "$abs_path"; return; }
	git_common_dir=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null) || { echo "$abs_path"; return; }

	# Make git-common-dir absolute
	if [[ "$git_common_dir" != /* ]]; then
		git_common_dir=$(cd "$git_toplevel" && realpath "$git_common_dir")
	fi
	main_root=$(dirname "$git_common_dir")

	# If toplevel differs from main root, we're in a worktree — rewrite the path
	if [ "$git_toplevel" != "$main_root" ]; then
		local relative="${abs_path#"$git_toplevel"}"
		debug "Remapped worktree path to main repo: ${main_root}${relative}"
		echo "${main_root}${relative}"
	else
		echo "$abs_path"
	fi
}

link_file() {
	local source="$1"
	local target="$2"
	local type="file" # Default to file
	if [ -d "$source" ]; then
		type="directory"
	fi

	# Check if target is a symlink first (including broken symlinks)
	if [ -L "$target" ]; then
		local link_dest
		link_dest=$(readlink "$target")

		# Resolve to absolute paths for comparison
		local resolved_source="$source"
		local resolved_link="$link_dest"

		# Resolve source path
		if command -v realpath >/dev/null 2>&1; then
			resolved_source=$(realpath "$source" 2>/dev/null || echo "$source")
		fi

		# Resolve symlink destination path
		if [[ "$link_dest" = /* ]]; then
			# Absolute path - try to resolve it
			if command -v realpath >/dev/null 2>&1; then
				# Try realpath first (works if file exists)
				resolved_link=$(realpath "$link_dest" 2>/dev/null || true)
				if [ -z "$resolved_link" ]; then
					# If realpath fails, use Python to resolve the path
					resolved_link=$(python3 -c "import os.path; print(os.path.abspath('$link_dest'))" 2>/dev/null || echo "$link_dest")
				fi
			else
				resolved_link="$link_dest"
			fi
		else
			# Relative path - make it absolute relative to target directory
			local full_path="$(dirname "$target")/$link_dest"
			if command -v realpath >/dev/null 2>&1; then
				resolved_link=$(realpath "$full_path" 2>/dev/null)
				if [ -z "$resolved_link" ]; then
					resolved_link=$(python3 -c "import os.path; print(os.path.abspath('$full_path'))" 2>/dev/null || echo "$full_path")
				fi
			else
				resolved_link="$full_path"
			fi
		fi

		if [ "$resolved_link" = "$resolved_source" ]; then
			debug "Symlink already in place: $target → $link_dest"
			return
		fi

		# Symlink points elsewhere - prompt or auto-resolve
		if [ "${DOT_SYMLINK_MODE:-interactive}" != "interactive" ]; then
			choice="${DOT_SYMLINK_MODE:0:1}"
		else
			user "Symlink '$target' points to '$link_dest'. [O]verride/[B]ackup/[S]kip?"
			read -r choice
		fi
		case "$choice" in
		[Oo])
			rm -f "$target" && ln -s "$source" "$target"
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
		return
	fi

	# Check if target exists as a regular file/directory
	if [ -e "$target" ]; then
		# Check if source and target are the same (shouldn't happen but safety check)
		local resolved_source="$source"
		local resolved_target="$target"
		if command -v realpath >/dev/null 2>&1; then
			resolved_source=$(realpath -m "$source" 2>/dev/null || echo "$source")
			resolved_target=$(realpath -m "$target" 2>/dev/null || echo "$target")
		fi

		if [[ "$resolved_source" == "$resolved_target" ]]; then
			debug "Source and target are the same. Skipping: $target"
			return
		fi

		# Regular file/directory exists - prompt or auto-resolve
		if [ "${DOT_SYMLINK_MODE:-interactive}" != "interactive" ]; then
			choice="${DOT_SYMLINK_MODE:0:1}"
		else
			user "The $type '$target' already exists. [O]verride/[B]ackup/[S]kip?"
			read -r choice
		fi
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
