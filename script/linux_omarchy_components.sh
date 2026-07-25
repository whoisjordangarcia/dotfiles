#!/bin/bash
#
# Single source of truth for the Omarchy component list.
# Sourced by linux_omarchy_installation.sh and bin/dot's module-selection menu.
#
# Dotfiles layered on top of an Omarchy (omarchy.org) install. Deliberately
# excludes components that fight Omarchy's own config management (see CLAUDE.md
# "Omarchy" notes):
#   hypr/linux, theming/linux, rofi/linux, btop/linux — HyDE-specific;
#     would break Omarchy's hyprland source-chain and theme system
#   vpn/linux, ufw/linux — Omarchy manages DNS (systemd-resolved) + ufw
#   dolphin/linux, brave/linux — Omarchy uses nautilus / omarchy-launch-browser

component_installation=(
	apps/omarchy
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
	# omarchy-safe hyprland overrides (never hyprland.conf/monitors.conf)
	hypr/omarchy
	gpu-switch/linux
	gh/linux
	fastfetch
	ssh
	codex
	claude
	agents
	# T2 MacBook Touch Bar (no-ops on non-T2 hardware)
	touchbar/arch
)
