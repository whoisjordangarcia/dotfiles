#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

source "$SCRIPT_DIR/common/log.sh"

# Fail on any command.
# set -eux pipefail

# Check for Homebrew and install if we don't have it
if test ! $(which brew); then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
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
if test ! $(which omz);
then
	info "omz exists!"
else
	info "installing oh-my-zsh..."
	info "make sure to add correct credentials"
	sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Setup Zsh
"$SCRIPT_DIR/zsh/setup.sh"