#!/bin/bash
#
# Single source of truth for the macOS component list.
# Sourced by mac_installation.sh, mac_work_installation.sh, and bin/dot
# (module selection menu) — edit here, never in the installers.
#
# Environment-specific components: append to the array inside the
# WORK_ENV conditional at the bottom.

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
  # brave/mac managed policies are opt-in: no-op unless DOT_BRAVE_MANAGED=1
  brave/mac
  sunshine/mac
  appearance-watcher/mac
)

# NOTE: keep "(" out of comments below — bin/dot's module parser
# (get_modules_from_script) text-scans this file for the array.
if [[ "${WORK_ENV:-}" == "1" ]]; then
  # Work-only components: append with component_installation+=...
  :
else
  # Personal-only components: append with component_installation+=...
  :
fi
