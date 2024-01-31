#!/bin/sh

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

(cd ~/git && git https://github.com/dracula/iterm.git)

# Check for Oh My Zsh and install if we don't have it
if test ! $(which omz); then
    echo "installing oh-my-zsh..."
    echo "make sure to add correct credentials"
    /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/HEAD/tools/install.sh)"
fi

# Setup Zsh
./script/zsh/setup.sh
