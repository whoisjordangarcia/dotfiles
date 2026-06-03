#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "$SCRIPT_DIR/script/common/log.sh"

# Configuration
DOTFILES_REPO="git@github.com:whoisjordangarcia/dotfiles.git"
DOTFILES_DIR="$HOME/dev/dotfiles"

# Main installation function
main() {
	echo ""

	# Check if dotfiles directory exists
	if [ -d "$DOTFILES_DIR" ]; then
		cd "$DOTFILES_DIR"
		git fetch origin || fail "Failed to fetch from origin"
		# Check if we're behind
		local behind=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo "0")
		if [ "$behind" -gt 0 ]; then
			git pull origin main || fail "Failed to pull latest changes"
		fi
	else
		mkdir -p "$(dirname "$DOTFILES_DIR")"
		git clone "$DOTFILES_REPO" "$DOTFILES_DIR" || fail "Failed to clone repository"
		cd "$DOTFILES_DIR"
	fi

	# Reattach stdin to the terminal so interactive prompts work
	# when piped via `curl | bash`
	exec </dev/tty

	if [[ $# -gt 0 ]]; then
		./bin/dot "$@"
	else
		./bin/dot -i
	fi
}

# Run main function
main "$@"
