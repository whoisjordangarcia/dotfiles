#!/bin/bash
set -euo pipefail

# Colors for output
RED="\033[0;31m"
GREEN="\033[00;32m"
YELLOW="\033[0;33m"
BLUE="\033[00;34m"
RESET="\033[0m"

# Configuration
DOTFILES_REPO="https://github.com/whoisjordangarcia/dotfiles.git"
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
	./bootstrap.sh || fail "Bootstrap failed"
}

# Run main function
main "$@"
