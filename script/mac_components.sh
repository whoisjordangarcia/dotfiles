#!/bin/bash
#
# Single source of truth for the macOS component list.
# Sourced by mac_installation.sh and bin/dot (module selection menu) —
# edit here, never in the installers.
#
# For an environment-specific component, append it inside a guard, e.g.
#   if [[ "${WORK_ENV:-}" == "1" ]]; then component_installation+=(some/work-only); fi
# (not `[[ … ]] && …`: false as the file's last line is a non-zero `source`
# under the installers' `set -e`)

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
  # code
  lazygit/mac
  claude
  agents
  codex
  pi
  fastfetch
  opencode
  herdr
  # music
  sonic-tui
  rmpc
  # brave/mac soft-installs extensions from configs/brave/extensions.txt (brave-sync)
  brave/mac
  sunshine/mac
  appearance-watcher/mac
  sd-backup/mac
)
