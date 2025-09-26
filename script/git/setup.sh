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

# GITCONFIG_TEMPLATE="$SCRIPT_DIR/../../configs/git/.gitconfig.template"
# GITCONFIG_TARGET="$HOME/.gitconfig"
#
# if [[ -f "$GITCONFIG_TEMPLATE" ]]; then
# 	# Always overwrite existing config to ensure updates
# 	info "Generating .gitconfig with current user values..."
#
# 	# Debug: Show what variables we have
# 	info "Debug: DOT_NAME='${DOT_NAME:-NOT_SET}'"
# 	info "Debug: DOT_EMAIL='${DOT_EMAIL:-NOT_SET}'"
# 	info "Debug: DOT_YUBIKEY='${DOT_YUBIKEY:-NOT_SET}'"
#
# 	# Remove existing file/symlink first
# 	rm -f "$GITCONFIG_TARGET"
# 	cp "$GITCONFIG_TEMPLATE" "$GITCONFIG_TARGET"
#
# 	# Replace placeholders with actual values using proper sed escaping
# 	if [[ -n "${DOT_NAME:-}" ]]; then
# 		sed -i "s|__DOT_NAME__|${DOT_NAME}|g" "$GITCONFIG_TARGET"
# 		info "Replaced __DOT_NAME__ with: $DOT_NAME"
# 	fi
#
# 	if [[ -n "${DOT_EMAIL:-}" ]]; then
# 		sed -i "s|__DOT_EMAIL__|${DOT_EMAIL}|g" "$GITCONFIG_TARGET"
# 		info "Replaced __DOT_EMAIL__ with: $DOT_EMAIL"
# 	fi
#
# 	if [[ -n "${DOT_YUBIKEY:-}" ]]; then
# 		sed -i "s|__DOT_YUBIKEY__|${DOT_YUBIKEY}|g" "$GITCONFIG_TARGET"
# 		info "Applied YubiKey: $DOT_YUBIKEY"
# 	else
# 		# Remove signing key lines if no YubiKey provided
# 		sed -i '/signingkey = __DOT_YUBIKEY__/d' "$GITCONFIG_TARGET"
# 		info "No YubiKey provided - removed signing configuration"
# 	fi
#
# 	success "Updated .gitconfig with: $DOT_NAME <$DOT_EMAIL>"
# else
# 	error "Git config template not found at $GITCONFIG_TEMPLATE"
# fi

link_file "$SCRIPT_DIR/../../configs/git/.gitconfig" "$HOME/.gitconfig"
link_file "$SCRIPT_DIR/../../configs/git/.gitignore_global" "$HOME/.gitignore_global"
link_file "$SCRIPT_DIR/../../configs/git/work.gitconfig" "$HOME/dev/work/.gitconfig"
