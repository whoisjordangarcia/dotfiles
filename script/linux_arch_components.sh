#!/bin/bash
#
# Single source of truth for the Arch Linux component list.
# Sourced by linux_arch_installation.sh and bin/dot's module-selection menu.

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
