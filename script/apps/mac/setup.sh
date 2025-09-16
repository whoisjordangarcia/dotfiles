#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"

# Parse command line arguments
FORCE_ENVIRONMENT=""
while [[ $# -gt 0 ]]; do
	case $1 in
	--work)
		FORCE_ENVIRONMENT="work"
		shift
		;;
	--personal)
		FORCE_ENVIRONMENT="personal"
		shift
		;;
	-h | --help)
		echo "Usage: $0 [--work|--personal]"
		echo "  --work      Force work environment setup"
		echo "  --personal  Force personal environment setup"
		echo "  If no flag is provided, environment is auto-detected"
		exit 0
		;;
	*)
		echo "Unknown option $1"
		exit 1
		;;
	esac
done

# Install xCode cli tools
if xcode-select -p &>/dev/null; then
	info "Xcode command line tools already installed. Skipping."
else
	info "Installing Xcode command line tools..."
	xcode-select --install
fi

# Check if Homebrew is installed
if ! command -v brew &>/dev/null; then
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

	echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>$HOME/.zprofile
	eval "$(/opt/homebrew/bin/brew shellenv)"
fi

brew analytics off

# Determine environment type
if [[ -n "$FORCE_ENVIRONMENT" ]]; then
	ENVIRONMENT="$FORCE_ENVIRONMENT"
elif [[ -n "${WORK_ENV:-}" ]] || [[ "$(git config user.email)" == *"@labcorp.com" ]]; then
	ENVIRONMENT="work"
else
	ENVIRONMENT="personal" # Default to personal
fi

info "Detected environment: $ENVIRONMENT"

# Install base packages first
info "Installing base packages..."
if [[ -f "$SCRIPT_DIR/Brewfile.base" ]]; then
	brew bundle --file="$SCRIPT_DIR/Brewfile.base"
else
	info "Brewfile.base not found, skipping base packages"
fi

# Install environment-specific packages
if [[ -f "$SCRIPT_DIR/Brewfile.$ENVIRONMENT" ]]; then
	info "Installing $ENVIRONMENT-specific packages..."
	brew bundle --file="$SCRIPT_DIR/Brewfile.$ENVIRONMENT"
else
	info "Brewfile.$ENVIRONMENT not found, falling back to legacy Brewfile"
	if [[ -f "$SCRIPT_DIR/Brewfile.legacy" ]]; then
		brew bundle --file="$SCRIPT_DIR/Brewfile.legacy"
	else
		info "No Brewfile found, skipping package installation"
	fi
fi

brew services start borders

# annoying things
defaults write -g ApplePressAndHoldEnabled -bool false
