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
	echo "Oh My Zsh is already installed."
fi

# Install powerlevel 10k
# using starship 12/20/24
#info "installing powerlevel10k..."
#git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

link_file "$ZSHRC_SOURCE" "$ZSHRC_TARGET"

link_file "$ZSHRC_MODULES_SOURCE" "$ZSHRC_MODULES_TARGET"

# Install zsh plugins
"$SCRIPT_DIR/../zsh/plugins/zsh_plugins.sh"

# Default zsh
info "Defaulting zsh..."
chsh -s $(which zsh)

chmod 600 ~/.zshrc

source ~/.zshrc
