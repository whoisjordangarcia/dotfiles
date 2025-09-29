#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# shellcheck source=../common/log.sh
source "$SCRIPT_DIR/../common/log.sh"
# shellcheck source=../common/symlink.sh
source "$SCRIPT_DIR/../common/symlink.sh"

DOT_NAME=${DOT_NAME:-}
DOT_EMAIL=${DOT_EMAIL:-}
DOT_YUBIKEY=${DOT_YUBIKEY:-}

if [ ! -d "$HOME/dev" ]; then
	mkdir "$HOME/dev"

	info "Created ~/dev folder"
fi

if [ ! -d "$HOME/dev/work" ]; then
	mkdir "$HOME/dev/work"

	info "Created ~/dev/work folder"
fi

GITCONFIG_TEMPLATE="$SCRIPT_DIR/../../configs/git/.gitconfig.template"
GITCONFIG_TARGET="$HOME/.gitconfig"

if [[ -f "$GITCONFIG_TEMPLATE" ]]; then
	# Always overwrite existing config to ensure updates
	debug "Generating .gitconfig with current user values..."

	# Debug: Show what variables we have
	debug "Debug: DOT_NAME='${DOT_NAME:-NOT_SET}'"
	debug "Debug: DOT_EMAIL='${DOT_EMAIL:-NOT_SET}'"
	debug "Debug: DOT_YUBIKEY='${DOT_YUBIKEY:-NOT_SET}'"

	# Configure sed for macOS (BSD) vs GNU differences
	if sed --version >/dev/null 2>&1; then
		SED_INLINE=(sed -i)
	else
		SED_INLINE=(sed -i '')
	fi

	# Remove existing file/symlink first
	rm -f "$GITCONFIG_TARGET"
	cp "$GITCONFIG_TEMPLATE" "$GITCONFIG_TARGET"

	# Replace placeholders with actual values using proper sed escaping
	if [[ -n "${DOT_NAME:-}" ]]; then
		"${SED_INLINE[@]}" "s|__DOT_NAME__|${DOT_NAME}|g" "$GITCONFIG_TARGET"
		debug "Replaced __DOT_NAME__ with: $DOT_NAME"
	fi

	if [[ -n "${DOT_EMAIL:-}" ]]; then
		"${SED_INLINE[@]}" "s|__DOT_EMAIL__|${DOT_EMAIL}|g" "$GITCONFIG_TARGET"
		debug "Replaced __DOT_EMAIL__ with: $DOT_EMAIL"
	fi

	if [[ -n "${DOT_YUBIKEY:-}" ]]; then
		"${SED_INLINE[@]}" "s|__DOT_YUBIKEY__|${DOT_YUBIKEY}|g" "$GITCONFIG_TARGET"
		info "Applied YubiKey: $DOT_YUBIKEY"
	else
		# Remove signing key lines if no YubiKey provided
		"${SED_INLINE[@]}" '/signingkey = __DOT_YUBIKEY__/d' "$GITCONFIG_TARGET"
		info "No YubiKey provided - removed signing configuration"
	fi

	DOT_DISPLAY_NAME=${DOT_NAME:-Unknown}
	DOT_DISPLAY_EMAIL=${DOT_EMAIL:-unknown@example.com}
	success "Updated .gitconfig with: ${DOT_DISPLAY_NAME} <${DOT_DISPLAY_EMAIL}>"
else
	error "Git config template not found at $GITCONFIG_TEMPLATE"
fi

# Removed conflicting symlink - using template generation above instead
link_file "$SCRIPT_DIR/../../configs/git/.gitignore_global" "$HOME/.gitignore_global"
link_file "$SCRIPT_DIR/../../configs/git/work.gitconfig" "$HOME/dev/work/.gitconfig"

# Configure git if DOT_NAME and DOT_EMAIL are provided
if [[ -n "$DOT_NAME" && -n "$DOT_EMAIL" ]]; then
	debug "Configuring git with provided credentials..."
	git config --global user.name "$DOT_NAME"
	git config --global user.email "$DOT_EMAIL"
	success "Git configured: $DOT_NAME <$DOT_EMAIL>"
fi
