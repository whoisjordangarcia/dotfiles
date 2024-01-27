#!/bin/bash

source "./script/common/log.sh"

# bootstrap installs things.

git config --global user.email "arickho@gmail.com"
git config --global user.name "Jordan Garcia"

# If we're on a Mac, let's install and setup homebrew.
if [ "$(uname -s)" == "Darwin" ]; then
  success "On Mac 👾 - installing dependencies"
  ./script/mac_installation.sh
else
  success "On Linux 👾 - Install dependencies"
  ./script/linux_installation.sh
fi

success "dependencies installed"

success "All installed! ✨"