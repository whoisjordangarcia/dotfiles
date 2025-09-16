#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/common/log.sh"

# Configure git if DOT_NAME and DOT_EMAIL are provided
if [[ -n "$DOT_NAME" && -n "$DOT_EMAIL" ]]; then
	info "Configuring git with provided credentials..."
	git config --global user.name "$DOT_NAME"
	git config --global user.email "$DOT_EMAIL"
	success "Git configured: $DOT_NAME <$DOT_EMAIL>"
fi

# Log environment information
info "Installation environment: ${DOT_ENVIRONMENT:-not set}"
if [[ "$DOT_ENVIRONMENT" == "work" ]]; then
	export WORK_ENV="1"
	info "Work environment detected - enabling work-specific configurations"
fi

component_installation=(
	apps/mac
	# essentials
	zsh
	vim
	tmux
	fonts/mac
	starship
	ghostty/mac
	git
	# code
	lazygit/mac
	#bun/mac
	claude/mac
	fastfetch
)

for component in "${component_installation[@]}"; do
	info "-- Running $component installation. --"
	script_path="./script/${component}/setup.sh"

	#Check if the script exists before trying to run it
	if [ -f "$script_path" ]; then
		bash "$script_path"
	else
		info "Script for $component does not exist."
	fi
done
