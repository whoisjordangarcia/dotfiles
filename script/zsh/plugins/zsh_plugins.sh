#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"

PLUGIN_DIR="$HOME/.zsh/plugins"

section "Installing zsh plugins"

mkdir -p "$PLUGIN_DIR"

# Install zsh-autosuggestions
if [ ! -d "$PLUGIN_DIR/zsh-autosuggestions" ]; then
    step "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$PLUGIN_DIR/zsh-autosuggestions"
else
    debug "zsh-autosuggestions already installed"
fi

# Install zsh-syntax-highlighting
if [ ! -d "$PLUGIN_DIR/zsh-syntax-highlighting" ]; then
    step "Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$PLUGIN_DIR/zsh-syntax-highlighting"
else
    debug "zsh-syntax-highlighting already installed"
fi

# nx-completion - Nx CLI completions
if [ ! -d "$PLUGIN_DIR/nx-completion" ]; then
    step "Installing nx-completion..."
    git clone https://github.com/jscutlery/nx-completion.git "$PLUGIN_DIR/nx-completion"
else
    debug "nx-completion already installed"
fi
