#!/bin/bash


info () {
  printf "\r  [ \033[00;34m..\033[0m ] $1\n"
}

user() {
	printf "\r  [ \033[0;33m??\033[0m ] $1\n"
}

success() {
	printf "\r\033[2K  [ \033[00;32mOK\033[0m ] $1\n"
}

fail() {
	printf "\r\033[2K  [\033[0;31mFAIL\033[0m] $1\n"
	echo ''
	exit
}

# Fail on any command.
set -eux pipefail

# Install ZSH
info "installing zsh..."
apt install zsh

# Install oh-my-zsh
info "installing oh-my-zsh..."
info "make sure to add correct credentials"
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install powerlevel 10k
info "installing powerlevel10k..."
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# Install nvm
info "installing nvm..."
curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash

source ~/.zshrc

# Default zsh
info "Defaulting zsh..."
chsh -s $(which zsh)

# Setup Zsh
./zsh/setup
