#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

ZSHRC_SOURCE="$SCRIPT_DIR/../../configs/zshrc/.zshrc"
ZSHRC_TARGET="$HOME/.zshrc"

# Install oh-my-zsh
#info "installing oh-my-zsh..."
#info "make sure to add correct credentials"
#sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install powerlevel 10k
# using starship 12/20/24
#info "installing powerlevel10k..."
#git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

link_file "$ZSHRC_SOURCE" "$ZSHRC_TARGET"

# Default zsh
info "Defaulting zsh..."
chsh -s $(which zsh)

# Install zsh plugins
"$SCRIPT_DIR/../zsh/plugins/zsh_plugins.sh"

source "~/.zshrc"
