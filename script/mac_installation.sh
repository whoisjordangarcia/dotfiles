#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/common/log.sh"

component_installation=(
	apps/mac
	git
	# essentials
	zsh
	vim
	neovim/mac
	tmux
	fonts/mac
	starship
	ghostty/mac
	# code
	lazygit/mac
	#bun/mac
	claude
	codex
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
