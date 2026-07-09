#!/bin/bash
set -euo pipefail

BRAVE_SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$BRAVE_SCRIPT_DIR/../../common/log.sh"
source "$BRAVE_SCRIPT_DIR/../soft_install.sh"
REPO_DIR=$(cd -- "$BRAVE_SCRIPT_DIR/../../.." &>/dev/null && pwd)

# Install Brave if missing
if [ ! -d "/Applications/Brave Browser.app" ]; then
	info "Brave Browser not found. Installing via Homebrew..."
	brew install --cask brave-browser
fi

# macOS reads external-extension manifests from the per-user data dir.
brave_soft_install \
	"$REPO_DIR/configs/brave/extensions.txt" \
	"$HOME/Library/Application Support/BraveSoftware/Brave-Browser/External Extensions"

# Per-profile colors (skips itself if Brave is running).
bash "$BRAVE_SCRIPT_DIR/../theme.sh"

info "Verify after restarting Brave at brave://extensions"
