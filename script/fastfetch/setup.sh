#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
COMPONENT_ROOT="$SCRIPT_DIR"
DOTFILES_ROOT=$(cd -- "$COMPONENT_ROOT/../.." &>/dev/null && pwd)

source "$COMPONENT_ROOT/../common/log.sh"
source "$COMPONENT_ROOT/../common/symlink.sh"

debug "Ensuring $HOME/.config/fastfetch exists"
mkdir -p "$HOME/.config/fastfetch"

# On server profiles, use minimal config as the default
if [[ "${DOT_SYSTEM:-}" == "linux_server" ]]; then
	link_file "$DOTFILES_ROOT/configs/fastfetch/config-minimal.jsonc" "$HOME/.config/fastfetch/config.jsonc"
else
	link_file "$DOTFILES_ROOT/configs/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
	link_file "$DOTFILES_ROOT/configs/fastfetch/config-minimal.jsonc" "$HOME/.config/fastfetch/config-minimal.jsonc"
fi
