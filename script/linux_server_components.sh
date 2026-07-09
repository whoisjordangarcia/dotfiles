#!/bin/bash
#
# Single source of truth for the Linux server (LXC) component list.
# Sourced by linux_server_installation.sh and bin/dot's module-selection menu.

component_installation=(
	apps/server
	git
	zsh
	vim-starter
	tmux
	zmx/linux
	starship
	fastfetch
	claude
	agents
)
