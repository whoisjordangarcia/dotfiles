#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"

section "Installing zsh plugins"

# Install zsh-autosuggestions
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
    step "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
else
    debug "zsh-autosuggestions already installed"
fi

# Install zsh-syntax-highlighting
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
    step "Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
else
    debug "zsh-syntax-highlighting already installed"
fi

# Install fzf plugin
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fzf-zsh-plugin" ]; then
    step "Installing fzf plugin..."
    git clone --depth 1 https://github.com/unixorn/fzf-zsh-plugin.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fzf-zsh-plugin
else
    debug "fzf plugin already installed"
fi

#no longer using
#info "Installing powerlevel10k.."
#git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# zsh-256color
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-256color" ]; then
    step "Installing zsh-256color..."
    git clone https://github.com/chrissicool/zsh-256color ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-256color
else
    debug "zsh-256color already installed"
fi

# ai
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh_codex" ]; then
    step "Installing zsh_codex..."
    git clone https://github.com/tom-doerr/zsh_codex.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh_codex
else
    debug "zsh_codex already installed"
fi

# nx-completion - Nx CLI completions
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/nx-completion" ]; then
    step "Installing nx-completion..."
    git clone git@github.com:jscutlery/nx-completion.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/nx-completion
else
    debug "nx-completion already installed"
fi
