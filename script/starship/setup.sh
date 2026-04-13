#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

# Install starship if not already installed
if ! command -v starship &>/dev/null; then
  info "Installing starship..."
  curl -sS https://starship.rs/install.sh | sh -s -- --yes
  success "starship installed"
else
  info "starship already installed: $(starship --version)"
fi

STARSHIP_SOURCE="$SCRIPT_DIR/../../configs/starship/starship.toml"
STARSHIP_TARGET="$HOME/.config/starship.toml"

link_file "$STARSHIP_SOURCE" "$STARSHIP_TARGET"

# Symlink prompt_info.sh for the custom starship module
mkdir -p "$HOME/.config/starship"
PROMPT_INFO_SOURCE="$SCRIPT_DIR/../../configs/starship/prompt_info.sh"
PROMPT_INFO_TARGET="$HOME/.config/starship/prompt_info.sh"

link_file "$PROMPT_INFO_SOURCE" "$PROMPT_INFO_TARGET"
chmod +x "$PROMPT_INFO_TARGET"
