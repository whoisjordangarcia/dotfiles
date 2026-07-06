#!/bin/bash
set -euo pipefail

# boot.sh is designed to be run via `curl -fsSL … | bash`, so it MUST be
# self-contained: the repo (and its script/common/log.sh) does not exist on
# disk until this script clones it below. Do NOT source anything from the repo
# here, and do NOT derive paths from ${BASH_SOURCE[0]} — when piped from stdin
# there is no script file, so BASH_SOURCE is empty (fatal under `set -u`).
# Keep a tiny inline logger that mirrors script/common/log.sh's style.
RED="\033[0;31m"
GREEN="\033[00;32m"
BLUE="\033[00;34m"
RESET="\033[0m"

info() { printf "\r$1\n" >&2; }
section() { printf "\r${BLUE}▶${RESET} ${BLUE}$1${RESET}\n" >&2; }
success() { printf "\r\033[2K${GREEN}OK${RESET} $1\n" >&2; }
fail() {
	printf "\r\033[2K${RED}FAIL${RESET} $1\n" >&2
	echo ''
	exit "${2:-1}"
}

# Configuration
# HTTPS (not SSH) so a fresh, keyless machine (e.g. a new LXC/server) can clone
# this public repo. On machines where you push, repoint origin afterward:
#   git -C "$DOTFILES_DIR" remote set-url origin git@github.com:whoisjordangarcia/dotfiles.git
DOTFILES_REPO="https://github.com/whoisjordangarcia/dotfiles.git"
DOTFILES_DIR="$HOME/dev/dotfiles"

# Main installation function
main() {
	echo ""

	command -v git &>/dev/null || fail "git is required but not installed"

	# Check if dotfiles directory exists
	if [ -d "$DOTFILES_DIR" ]; then
		section "Updating existing dotfiles at $DOTFILES_DIR"
		cd "$DOTFILES_DIR"
		git fetch origin || fail "Failed to fetch from origin"
		# Check if we're behind
		local behind
		behind=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo "0")
		if [ "$behind" -gt 0 ]; then
			git pull origin main || fail "Failed to pull latest changes"
		fi
	else
		section "Cloning dotfiles into $DOTFILES_DIR"
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
