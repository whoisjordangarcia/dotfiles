#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/common/log.sh"

# Fail on any command.
# set -eux pipefail

# Check for Homebrew and install if we don't have it
if test ! $(which brew); then
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

	echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>$HOME/.zprofile
	eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Install all our dependencies with bundle (See Brewfile)
brew tap homebrew/bundle
brew bundle --file Brewfile

if [ ! -d "~/git" ]; then
	mkdir ~/git
fi

(cd ~/git && git clone https://github.com/dracula/iterm.git)

# Check for Oh My Zsh and install if we don't have it
if test ! $(which omz); then
	info "omz exists!"
else
	info "installing oh-my-zsh..."
	info "make sure to add correct credentials"
	sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Setup Zsh
"$SCRIPT_DIR/zsh/setup.sh"

# Setup setup vim
"$SCRIPT_DIR/vim/setup.sh"

# Install tmux
brew install tmux
"$SCRIPT_DIR/tmux/setup.sh"

# Install fzf
brew install fzf

# Install lolcat
brew install lolcat

# Install figlet
brew install figlet

# Install fzf
brew install fzf

# Install neovim
brew install neovim

# Install git-town
brew install git-town

# Install eza
brew install eza
