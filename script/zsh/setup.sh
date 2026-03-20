#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/../common/symlink.sh"

ZSHRC_SOURCE="$SCRIPT_DIR/../../configs/zshrc/.zshrc"
ZSHRC_TARGET="$HOME/.zshrc"

ZSHRC_MODULES_SOURCE="$SCRIPT_DIR/../../configs/zshrc/.zshrc-modules"
ZSHRC_MODULES_TARGET="$HOME/.zshrc-modules"

# Create plugin directory
mkdir -p "$HOME/.zsh/plugins"

link_file "$ZSHRC_SOURCE" "$ZSHRC_TARGET"

# Symlink individual module files (preserves local-only files like .zshrc.sec)
mkdir -p "$ZSHRC_MODULES_TARGET"
for source_file in "$ZSHRC_MODULES_SOURCE"/.*; do
	[[ "$(basename "$source_file")" == "." || "$(basename "$source_file")" == ".." ]] && continue
	link_file "$source_file" "$ZSHRC_MODULES_TARGET/$(basename "$source_file")"
done

# Symlink scripts subdirectory
if [ -d "$ZSHRC_MODULES_SOURCE/scripts" ]; then
	link_file "$ZSHRC_MODULES_SOURCE/scripts" "$ZSHRC_MODULES_TARGET/scripts"
fi

# Inject secrets from 1Password template
SECRETS_TPL="$ZSHRC_MODULES_SOURCE/.zshrc.sec.tpl"
SECRETS_OUT="$ZSHRC_MODULES_TARGET/.zshrc.sec"
if [ -f "$SECRETS_TPL" ]; then
	if command -v op &>/dev/null && op whoami &>/dev/null 2>&1; then
		op inject -i "$SECRETS_TPL" -o "$SECRETS_OUT"
		chmod 600 "$SECRETS_OUT"
		success "Secrets injected from 1Password"
	else
		info "1Password CLI not available or not signed in. Skipping secrets injection."
		info "Run 'op signin' then re-run bootstrap to inject secrets."
	fi
fi

# Install zsh plugins
"$SCRIPT_DIR/../zsh/plugins/zsh_plugins.sh"

# Default zsh
CURRENT_SHELL=$(basename "$SHELL")
ZSH_PATH="$(command -v zsh)"

if [ "$CURRENT_SHELL" != "zsh" ]; then
	info "Defaulting zsh..."
	sudo -s "$ZSH_PATH"
else
	debug "Shell is already zsh. Skipping."
fi

chmod 600 "$HOME/.zshrc"
