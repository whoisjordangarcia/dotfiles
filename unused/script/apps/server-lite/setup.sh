#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"

step "Installing minimal apt packages (server-lite)"
sudo apt-get update -qq
sudo apt-get install -y \
	tmux \
	git \
	curl \
	ca-certificates \
	jq

success "server-lite packages installed"
