#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

ZSHRC_SOURCE="$SCRIPT_DIR/../../configs/zshrc/.zshrc"
ZSHRC_TARGET="$HOME/.zshrc"

ZSHRC_MODULES_SOURCE="$SCRIPT_DIR/../../configs/zshrc/.zshrc-modules"
ZSHRC_MODULES_TARGET="$HOME/.zshrc-modules"

# Install oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
	info "Installing Oh My Zsh..."
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
	debug "Oh My Zsh already installed. Skipping."
fi

link_file "$ZSHRC_SOURCE" "$ZSHRC_TARGET"

link_file "$ZSHRC_MODULES_SOURCE" "$ZSHRC_MODULES_TARGET"

# Install zsh plugins
"$SCRIPT_DIR/../zsh/plugins/zsh_plugins.sh"

# Default zsh
CURRENT_SHELL=$(basename "$SHELL")
ZSH_PATH="$(command -v zsh)"

if [ "$CURRENT_SHELL" != "zsh" ]; then
	info "Defaulting zsh..."
	sudo chsh -s "$ZSH_PATH"
else
	debug "Shell is already zsh. Skipping."
fi

chmod 600 "$HOME/.zshrc"
