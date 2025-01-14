#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

if [ ! -d "$HOME/dev" ]; then
	mkdir "$HOME/dev"

	info "Created ~/dev folder"
fi

if [ ! -d "$HOME/dev/work" ]; then
	mkdir "$HOME/dev/work"

	info "Created ~/dev/work folder"
fi

link_file "$SCRIPT_DIR/../../configs/git/.gitconfig" "$HOME/.gitconfig"
link_file "$SCRIPT_DIR/../../configs/git/.gitignore_global" "$HOME/.gitignore_global"
link_file "$SCRIPT_DIR/../../configs/git/work.gitconfig" "$HOME/dev/work/.gitconfig"
