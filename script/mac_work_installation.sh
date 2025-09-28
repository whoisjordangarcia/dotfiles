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

# Set work environment
export WORK_ENV="1"
export DOT_ENVIRONMENT="work"
status "Work installation - enabling work-specific configurations"

component_installation=(
	apps/mac
	git
	zsh
	vim
	tmux
	fonts/mac
	aerospace/mac
	lazygit/mac
	starship
	work/mac
	claude
	codex
	fastfetch
)

for component in "${component_installation[@]}"; do
	section "$component"
	script_path="./script/${component}/setup.sh"

	#Check if the script exists before trying to run it
	if [ -f "$script_path" ]; then
		source "$script_path"
	else
		fail "Script for $component does not exist."
	fi
done
