#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"

# Install nvm
if [ -d "${HOME}/.nvm/.git" ] || [ -d "${HOME}/.config/nvm/.git" ] || command -v nvm >/dev/null 2>&1; then
	success "nvm already installed. Skipping installation."
else
	info "installing nvm..."
	curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
fi
