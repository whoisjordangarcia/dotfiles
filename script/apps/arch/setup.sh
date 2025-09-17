#!/bin/bash
set -euo pipefail

# Official repo packages (pretty and safe formatting)
PACKAGES=(
	# Shell
	zsh
	starship

	# Development Tools
	gh
	neovim

	# CLI utils
	tmux
	ripgrep
	eza
	zoxide
	wl-clipboard
	fzf
	jq
	bat

	# System monitors
	dysk
	htop
	btop

	# Fonts
	ttf-jetbrains-mono-nerd

	# Desktop/Games
	gamemode
	mangohud

	# Apps (official repos)
	darktable
)

sudo pacman -S --needed "${PACKAGES[@]}"

# AUR apps (installed with yay if present)
AUR_PKGS=(
	ghostty-git
	spotify_player
)

if command -v yay >/dev/null 2>&1; then
	# Use yay for AUR only; keep it interactive by default
	yay -S --aur --needed --sudoloop --removemake --cleanafter "${AUR_PKGS[@]}"
else
	echo "[apps/arch] 'yay' not found; skipping AUR apps: ${AUR_PKGS[*]}"
	echo "Install yay and re-run to include AUR apps."
fi
