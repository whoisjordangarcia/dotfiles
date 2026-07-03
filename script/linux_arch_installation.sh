#!/bin/bash

source ./script/common/log.sh

component_installation=(
	apps/arch
	# code
	git
	notes
	node
	lazygit/linux
	# essentials
	zsh
	vim
	tmux
	zmx/linux
	bat/linux
	ghostty/linux
	fonts/linux
	starship
	# symlinks custom overrides on top of HyDE
	hypr/linux
	theming/linux
	rofi/linux
	btop/linux
	gh/linux
	brave/linux
	fastfetch
	ssh
	codex
	claude
	agents
	dolphin/linux
	vpn/linux
	ufw/linux
	# T2 MacBook Touch Bar (tiny-dfr drop-in; no-ops on non-T2 hardware)
	touchbar/arch
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
