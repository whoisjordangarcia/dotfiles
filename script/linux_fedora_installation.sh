##!/bin/bash

source ./script/common/log.sh

component_installation=(
	apps/fedora
	# code
	git
	zsh
	vim
	tmux
	lazygit/fedora
	# essentials
	fonts/linux
	i3
	polybar
	starship
	fastfetch
)

for component in "${component_installation[@]}"; do
	section "$component"
	script_path="./script/${component}/setup.sh"

	#Check if the script exists before trying to run it
	if [ -f "$script_path" ]; then
		source "$script_path"
	else
		info "Script for $component does not exist."
	fi
done
