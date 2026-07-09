#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../soft_install.sh"
REPO_DIR=$(cd -- "$SCRIPT_DIR/../../.." &>/dev/null && pwd)

# Check Brave is installed (install paths vary by distro — leave to the user)
if ! command -v brave-browser &>/dev/null && ! command -v brave &>/dev/null; then
	info "Brave Browser not found — install from https://brave.com/linux/ then re-run. Skipping."
	exit 0
fi

# ponytail: Linux external-extension autoload is less documented than macOS — some
# builds only scan a system dir (/usr/share/brave/extensions). If the extensions
# don't show at brave://extensions after restart, Brave Sync is the reliable
# cross-machine fallback; upgrade this to the system dir if that's your build.
brave_soft_install \
	"$REPO_DIR/configs/brave/extensions.txt" \
	"$HOME/.config/BraveSoftware/Brave-Browser/External Extensions"

# Per-profile colors (skips itself if Brave is running).
bash "$SCRIPT_DIR/../theme.sh"

info "Verify after restarting Brave at brave://extensions"
