#!/bin/bash
set -euo pipefail

# Official repo packages (pretty and safe formatting)
PACKAGES=(
	# Shell
	zsh
	starship

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
	mangohud

	# Apps (official repos)
	darktable

	# Containers
	podman-desktop
	podman
	podman-docker

	# smart card
	yubikey-manager
	yubikey-personalization
	ccid
	pcsclite
	gnupg
)

if pacman -Qi docker-desktop >/dev/null 2>&1; then
	echo "[apps/arch] Removing docker-desktop in favor of podman-desktop"
	sudo pacman -Rns --noconfirm docker-desktop
else
	echo "[apps/arch] docker-desktop not installed; skipping removal"
fi

if pacman -Qi docker >/dev/null 2>&1; then
	echo "[apps/arch] Removing docker CLI to avoid conflicts with podman-docker"
	sudo pacman -Rns --noconfirm docker
else
	echo "[apps/arch] docker CLI not installed; skipping removal"
fi

sudo pacman -S --needed "${PACKAGES[@]}"

# Ensure rootless Podman can configure user namespaces
ensure_setuid() {
	local binary="$1"

	if [[ -x "$binary" && ! -u "$binary" ]]; then
		echo "[apps/arch] Enabling setuid on $binary for rootless Podman"
		sudo chmod u+s "$binary"
	fi
}

ensure_setuid /usr/bin/newuidmap
ensure_setuid /usr/bin/newgidmap

# AUR apps (installed with yay if present)
AUR_PKGS=(
	ghostty-git
	neovim-nightly-bin
)

if command -v yay >/dev/null 2>&1; then
	# Use yay for AUR only; keep it interactive by default
	yay -S --aur --needed --sudoloop --removemake --cleanafter "${AUR_PKGS[@]}"
else
	echo "[apps/arch] 'yay' not found; skipping AUR apps: ${AUR_PKGS[*]}"
	echo "Install yay and re-run to include AUR apps."
fi
