#!/bin/bash

source "./script/common/log.sh"

# Check for --reconfigure flag
if [[ "$1" == "--reconfigure" ]]; then
    ./bin/dot --reconfigure
else
    # Run dotfiles setup (will use existing config if available, or prompt if not)
    ./bin/dot
fi

success "✨✨ -- Dotfiles installation completed successfully! -- ✨✨"