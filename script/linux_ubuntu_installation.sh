#!/bin/bash

source ./script/common/log.sh

component_installation=(
	apps/ubuntu
	git
	notes
	zsh
	vim
	tmux
	node
	lazygit/linux
	starship
	fastfetch
	ssh
	brave/linux
)

for component in "${component_installation[@]}"; do
	section "$component"
	script_path="./script/${component}/setup.sh"

	if [ -f "$script_path" ]; then
		source "$script_path"
	else
		info "Script for $component does not exist."
	fi
done
