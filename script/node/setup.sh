#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/dot_env.sh"
dot_export_env

# Install nvm
if [ -d "${HOME}/.nvm/.git" ] || [ -d "${HOME}/.config/nvm/.git" ] || command -v nvm >/dev/null 2>&1; then
	debug "nvm already installed. Skipping installation."
else
	info "installing nvm..."
	curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
	success "nvm installed."
fi

# Load nvm into current shell session
export NVM_DIR="${HOME}/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install LTS node if no version is active
if ! command -v node &>/dev/null; then
	info "installing node LTS via nvm..."
	nvm install --lts
	nvm use --lts
	success "node installed."
else
	debug "node already available. Skipping."
fi

# Socket Firewall — work only; the npm/pnpm aliases in .zshrc.work gate on this binary
if [[ "$DOT_ENV" == "work" ]]; then
	if command -v npm &>/dev/null; then
		info "installing sfw (Socket Firewall)..."
		npm install -g sfw
		success "sfw installed."
	else
		info "npm not found — skipping sfw install. Run 'npm install -g sfw' manually."
	fi
fi
