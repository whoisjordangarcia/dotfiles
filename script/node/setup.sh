#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"

# Install nvm
if [ -d "${HOME}/.nvm/.git" ]; then
	info "nvm already installed..."
else
	info "installing nvm..."
	curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
fi
