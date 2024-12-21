#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"

(cd ~/git 2>/dev/null || cd ~/dev && git clone https://github.com/catppuccin/iterm.git)
info "-- catppuccin theme for iterm2 is complete. Install theme manually"
