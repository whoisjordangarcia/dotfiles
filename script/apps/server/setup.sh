#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"

# ── Core apt packages ───────────────────────────────────────────────
step "Installing core apt packages"
sudo apt-get update -qq
sudo apt-get install -y \
	zsh \
	tmux \
	ripgrep \
	fzf \
	git \
	curl \
	wget \
	unzip \
	gpg \
	build-essential

# ── Neovim (unstable PPA for treesitter support) ───────────────────
if ! command -v nvim &>/dev/null; then
	step "Installing Neovim (unstable PPA)"
	sudo apt-get install -y software-properties-common
	sudo add-apt-repository -y ppa:neovim-ppa/unstable
	sudo apt-get update -qq
	sudo apt-get install -y neovim
else
	info "Neovim already installed: $(nvim --version | head -1)"
fi

# ── eza (modern ls replacement) ────────────────────────────────────
if ! command -v eza &>/dev/null; then
	step "Installing eza"
	sudo mkdir -p /etc/apt/keyrings
	wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
	echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
	sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
	sudo apt-get update -qq
	sudo apt-get install -y eza
else
	info "eza already installed"
fi

# ── Starship prompt ────────────────────────────────────────────────
if ! command -v starship &>/dev/null; then
	step "Installing Starship"
	curl -sS https://starship.rs/install.sh | sh -s -- -y
else
	info "Starship already installed: $(starship --version)"
fi

# ── Fastfetch ──────────────────────────────────────────────────────
if ! command -v fastfetch &>/dev/null; then
	step "Installing Fastfetch"
	sudo apt-get install -y fastfetch 2>/dev/null || {
		info "Fastfetch not in apt, installing from GitHub release"
		local_arch=$(dpkg --print-architecture)
		latest_url=$(curl -sL "https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest" \
			| grep "browser_download_url.*linux-${local_arch}.*\.deb" \
			| head -1 \
			| cut -d '"' -f 4)
		if [[ -n "$latest_url" ]]; then
			curl -sLo /tmp/fastfetch.deb "$latest_url"
			sudo dpkg -i /tmp/fastfetch.deb
			rm -f /tmp/fastfetch.deb
		else
			info "Could not find fastfetch deb for ${local_arch}, skipping"
		fi
	}
else
	info "Fastfetch already installed"
fi

# ── Node.js (via nodesource, needed for nvim LSP/tooling) ─────────
if ! command -v node &>/dev/null; then
	step "Installing Node.js (via nodesource)"
	curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
	sudo apt-get install -y nodejs
else
	info "Node.js already installed: $(node --version)"
fi

# Claude Code is installed via script/claude/setup.sh

# ── zoxide (smart cd) ─────────────────────────────────────────────
if ! command -v zoxide &>/dev/null; then
	step "Installing zoxide"
	curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
else
	info "zoxide already installed"
fi

success "Server packages installed"
