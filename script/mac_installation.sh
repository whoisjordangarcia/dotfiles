#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/common/log.sh"
source "$SCRIPT_DIR/common/check_ssh.sh"

section "Preflight checks"
check_github_ssh

component_installation=(
  apps/mac
  1password/mac
  git
  ssh
  gh/mac
  notes
  # essentials
  zsh
  vim
  node
  neovim/mac
  tmux
  fonts/mac
  starship
  rift/mac
  ghostty/mac
  # code
  lazygit/mac
  #bun/mac
  claude
  claude-mem
  codex
  fastfetch
  opencode
  brave/mac
  sunshine/mac
)

for component in "${component_installation[@]}"; do
  section "$component"
  script_path="./script/${component}/setup.sh"

  #Check if the script exists before trying to run it
  if [ -f "$script_path" ]; then
    source "$script_path"
  else
    info "Script for $component does not exist."
  fi
done

header "Installation Complete"
success "All components installed successfully!"
info "Restart your terminal or run: source ~/.zshrc"
