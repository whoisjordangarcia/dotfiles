##!/bin/bash

source ./script/common/log.sh

sudo apt update
sudo apt install -y \
	gcc \
	zsh \
	gh \
	lolcat \
	figlet \
	tmux \
	ripgrep \
	autojump \
	eza \
	neovim \
	tmux \
	python3-neovim

component_installation=(
	zsh
	vim
	tmux
	node
	git
	weztern
	fonts/linux
)

for component in "${component_installation[@]}"; do
	info "-- Running $component installation. --"
	script_path="./script/${component}/setup.sh"

	#Check if the script exists before trying to run it
	if [ -f "$script_path" ]; then
		bash "$script_path"
	else
		info "Script for $component does not exist."
	fi
done

# lazygit ubuntu
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit /usr/local/bin
