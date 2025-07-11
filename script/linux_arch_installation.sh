##!/bin/bash

source ./script/common/log.sh

component_installation=(
	apps/arch
	# code
	node
	git
	lazygit/linux
	# essentials
	zsh
	vim
	tmux
	ghostty/linux
	fonts/linux
	starship
	# now using HyDE
	#hypr/linux
	#waybar/linux
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
