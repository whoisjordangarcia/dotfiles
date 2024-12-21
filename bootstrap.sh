#!/bin/bash

source "./script/common/log.sh"

# bootstrap installs things.
git config --global user.email "arickho@gmail.com"
git config --global user.name "Jordan Garcia"

# Check file used for Linux machines
[ -f /etc/os-release ] && source /etc/os-release

if [ "$(uname -s)" == "Darwin" ]; then
	success "On Mac 💻 - installing dotfiles"
	./script/mac_installation.sh
elif [ "$ID" == "fedora" ]; then
	success "On Linux - Fedora 🎩 - Install dotfiles"
	./script/linux_fedora_installation.sh
elif [ "$ID" == "ubuntu" ]; then
	success "On Ubuntu - Linux 👾 - Install dotfiles"
	./script/linux_ubuntu_installation.sh
elif [ "$ID" == "arch" ]; then
	success "On Arch   - Install dotfiles"
	./script/linux_arch_installation.sh
else
	fail "Unhandled Error"
fi

success "✨✨ -- All installed! -- ✨✨"
