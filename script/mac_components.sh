#!/bin/bash
#
# Single source of truth for the macOS component list.
# Sourced by mac_installation.sh and bin/dot (module selection menu) —
# edit here, never in the installers.
#
# For an environment-specific component, append it inside a guard, e.g.
#   [[ "${WORK_ENV:-}" == "1" ]] && component_installation+=(some/work-only)

component_installation=(
  apps/mac
  macos
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
  starship
  rift/mac
  ghostty/mac
  cmux
  # code
  lazygit/mac
  claude
  agents
  codex
  fastfetch
  opencode
  # music
  sonic-tui
  rmpc
  # brave/mac soft-installs extensions from configs/brave/extensions.txt (brave-sync)
  brave/mac
  sunshine/mac
  appearance-watcher/mac
)
