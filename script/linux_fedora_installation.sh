##!/bin/bash

source ./script/common/log.sh

# Install ZSH
info "installing zsh..."
pkcon install zsh

# Install oh-my-zsh
info "installing oh-my-zsh..."
info "make sure to add correct credentials"
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install powerlevel 10k
info "installing powerlevel10k..."
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# Install nvm
if [ -d "${HOME}/.nvm/.git" ]; then
	info "nvm already installed..."
else
	info "installing nvm..."
	curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
fi

source $HOME/.zshrc

# git
pkcon install gh

# Default zsh
info "Defaulting zsh..."
chsh -s $(which zsh)

# Setup Zsh
./script/zsh/setup.sh

# Setup Vim
pkcon install -y neovim python3-neovim

pkcon install lolcat
pkcon install figlet

pkcon install autojump

./script/vim/setup.sh

LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit /usr/local/bin
