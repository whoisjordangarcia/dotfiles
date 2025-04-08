#!/bin/bash

source "./script/common/log.sh"

# Check file used for Linux machines
[ -f /etc/os-release ] && source /etc/os-release

if [ "$(uname -s)" == "Darwin" ]; then
	success "Platform: MacOS 💻 - Initiating dotfiles installation."
	./script/mac_installation.sh
elif [ "$ID" == "fedora" ]; then
	success "Platform: Fedora 🎩 - Initiating dotfiles installation."
	./script/linux_fedora_installation.sh
elif [ "$ID" == "ubuntu" ]; then
	success "Platform: Ubuntu 👾 - Initiating dotfiles installation."
	./script/linux_ubuntu_installation.sh
elif [ "$ID" == "arch" ]; then
	success "Platform: Arch   - Initiating dotfiles installation."
	./script/linux_arch_installation.sh
else
	fail "Error: Unsupported platform."
fi

success "✨✨ -- Dotfiles installation completed successfully! -- ✨✨"
