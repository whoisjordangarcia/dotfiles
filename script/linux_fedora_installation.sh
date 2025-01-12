##!/bin/bash

source ./script/common/log.sh

component_installation=(
	apps/fedora
	# code
	zsh
	vim
	tmux
	node
	git
	lazygit/fedora
	# essentials
	fonts/linux
	i3
	polybar
	starship
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
