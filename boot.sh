#!/bin/bash
set -euo pipefail

# Colors for output
RED="\033[0;31m"
GREEN="\033[00;32m"
YELLOW="\033[0;33m"
BLUE="\033[00;34m"
RESET="\033[0m"

# Simple logging functions
info() {
	printf "\r  [ ${BLUE}..${RESET} ] $1\n" >&2
}

success() {
	printf "\r\033[2K  [ ${GREEN}OK${RESET} ] $1\n" >&2
}

fail() {
	printf "\r\033[2K  [ ${RED}FAIL${RESET} ] $1\n" >&2
	exit 1
}

# Configuration
DOTFILES_REPO="https://github.com/whoisjordangarcia/dotfiles.git"
DOTFILES_DIR="$HOME/dev/dotfiles"

# Main installation function
main() {
	echo ""

	# Check if dotfiles directory exists
	if [ -d "$DOTFILES_DIR" ]; then
		info "Dotfiles directory found. Updating..."
		cd "$DOTFILES_DIR"

		# Fetch latest changes
		info "Fetching latest changes..."
		git fetch origin || fail "Failed to fetch from origin"

		# Check if we're behind
		local behind=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo "0")
		if [ "$behind" -gt 0 ]; then
			info "Pulling $behind new commits..."
			git pull origin main || fail "Failed to pull latest changes"
			success "Updated to latest version"
		else
			success "Already up to date"
		fi
	else
		info "Cloning dotfiles repository..."

		# Create parent directory if needed
		mkdir -p "$(dirname "$DOTFILES_DIR")"

		# Clone the repository
		git clone "$DOTFILES_REPO" "$DOTFILES_DIR" || fail "Failed to clone repository"
		cd "$DOTFILES_DIR"
		success "Repository cloned successfully"
	fi

	# Run the bootstrap script
	info "Starting dotfiles installation..."
	echo ""
	./bootstrap.sh || fail "Bootstrap failed"
}

# Run main function
main "$@"
