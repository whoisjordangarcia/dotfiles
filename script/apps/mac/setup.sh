#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"

# Check if Homebrew is installed
if ! command -v brew &>/dev/null; then
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

	echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>$HOME/.zprofile
	eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Tap Homebrew Bundle if not already tapped
if ! brew tap | grep -q '^homebrew/bundle$'; then
	info "Tapping homebrew/bundle..."
	brew tap homebrew/bundle
fi

info "Installing and upgrading apps from Brewfile..."
brew bundle --file=Brewfile
