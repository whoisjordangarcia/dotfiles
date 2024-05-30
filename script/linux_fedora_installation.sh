##!/bin/bash

source ./script/common/log.sh

pkcon install -y \
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
	python3-neovim \
	zoxide

component_installation=
	zsh
	vim
	tmux
	node
	git
	wezterm
	fonts/linux
  i3
  polybar
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
