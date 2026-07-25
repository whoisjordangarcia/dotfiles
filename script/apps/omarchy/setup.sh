#!/bin/bash
set -euo pipefail

# Omarchy-safe package set. Omarchy already ships the desktop stack
# (hyprland, waybar, walker, mako, docker, ufw, ...) — this only layers
# CLI/dev tooling on top. Deliberately NOT installed here:
#   podman-docker — conflicts=docker; would rip out Omarchy's docker stack
#   dnsmasq/ufw/wireguard-tools — vpn-split + ufw components are desktop-only;
#     Omarchy manages DNS (systemd-resolved) and its own ufw rules
#   mangohud, darktable — desktop-machine extras (linux_arch profile)
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
	github-cli

	# System monitors
	dysk
	htop
	btop

	# Fonts
	ttf-jetbrains-mono-nerd
	ttf-gohu-nerd
	ttf-terminus-nerd

	# Game streaming client (Apollo/Sunshine host runs on the desktop)
	moonlight-qt

	# Containers (podman alongside Omarchy's docker — no docker shim)
	podman-desktop
	podman

	# smart card
	yubikey-manager
	yubikey-personalization
	ccid
	pcsclite
	gnupg
)

sudo pacman -S --needed "${PACKAGES[@]}"

# Ensure rootless Podman can configure user namespaces
ensure_setuid() {
	local binary="$1"

	if [[ -x "$binary" && ! -u "$binary" ]]; then
		echo "[apps/omarchy] Enabling setuid on $binary for rootless Podman"
		sudo chmod u+s "$binary"
	fi
}

ensure_setuid /usr/bin/newuidmap
ensure_setuid /usr/bin/newgidmap

# AUR apps (installed with yay if present)
AUR_PKGS=(
	1password-cli
	ghostty-git
	neovim-nightly-bin
	claude-desktop-appimage
)

if command -v yay >/dev/null 2>&1; then
	# Use yay for AUR only; keep it interactive by default
	yay -S --aur --needed --sudoloop --removemake --cleanafter "${AUR_PKGS[@]}"
else
	echo "[apps/omarchy] 'yay' not found; skipping AUR apps: ${AUR_PKGS[*]}"
	echo "Install yay and re-run to include AUR apps."
fi
