##!/bin/bash

source ./script/common/log.sh

pkcon install -y \
	zsh \
	neovim \
	python3-neovim \
	gh \
	lolcat \
	figlet \
	ripgrep \
	autojump

component_installation=(
	zsh
	vim
	tmux
	node
	git
)

for component in "${component_installation[@]}"; do
	info "Running $component installation."
	script_path="./script/${component}/setup.sh"

	#Check if the script exists before trying to run it
	if [ -f "$script_path" ]; then
		bash "$script_path"
	else
		info "Script for $component does not exist."
	fi
done

# lazygit fedora
sudo dnf copr enable atim/lazygit -y
sudo dnf install lazygit
