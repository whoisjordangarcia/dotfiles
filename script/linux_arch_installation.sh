##!/bin/bash

source ./script/common/log.sh

pacman -S \
	zsh \
	gh \
	lolcat \
	figlet \
	tmux \
	ripgrep \
	eza \
	neovim \
	tmux \
	zoxide \
	wezterm \
	figlet \
	lolcat \
	ttf-jetbrains-mono-nerd \
	brillo \
	wl-clipboard \ # makes clipboard work in nvim
unzip

component_installation=(
	zsh
	vim
	tmux
	node
	git
	wezterm
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
