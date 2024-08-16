#!/bin/bash

source "./script/common/log.sh"

# bootstrap installs things.

git config --global user.email "arickho@gmail.com"
git config --global user.name "Jordan Garcia"

source /etc/os-release

# If we're on a Mac, let's install and setup homebrew.
if [ "$(uname -s)" == "Darwin" ]; then
  success "On Mac 👾 - installing dependencies"
  ./script/mac_installation.sh
elif [ "$ID" == "fedora" ]; then
  success "On Linux - Fedora 👾 - Install dependencies"
  ./script/linux_fedora_installation.sh
elif [ "$ID" == "ubuntu" ]; then
  success "On Ubuntu - Linux 👾 - Install dependencies"
  ./script/linux_ubuntu_installation.sh
elif [ "$ID" == "arch" ]; then
  success "On Arch - Linux 👾 - Install dependencies"
  ./script/linux_arch_installation.sh
else 
  fail "Unhandled Error" 
fi

success "dependencies installed"

success "All installed! ✨"
