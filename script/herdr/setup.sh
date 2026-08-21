#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"

# The installer drops a single checksum-verified binary in ~/.local/bin, which
# isn't necessarily on this child process's PATH — so check the path too, or a
# re-run reinstalls every time.
if command -v herdr &>/dev/null || [[ -x "$HOME/.local/bin/herdr" ]]; then
	debug "Herdr is already installed, skipping installation..."
else
	info "Installing Herdr..."
	curl -fsSL https://herdr.dev/install.sh | sh
	success "Herdr installation completed!"
fi
