#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/common/log.sh"

component_installation=(
	apps/mac
	# essentials
	zsh
	vim
	tmux
	fonts/mac
	aerospace/mac
	starship
	ghostty/mac
	# code
	lazygit/mac
	#bun/mac
	#iterm2/mac
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
