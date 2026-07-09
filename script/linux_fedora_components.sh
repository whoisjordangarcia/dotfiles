#!/bin/bash
#
# Single source of truth for the Fedora component list.
# Sourced by linux_fedora_installation.sh and bin/dot's module-selection menu.

component_installation=(
	apps/fedora
	# code
	git
	notes
	zsh
	vim
	tmux
	zmx/linux
	lazygit/fedora
	# essentials
	fonts/linux
	polybar
	starship
	fastfetch
	brave/linux
)
