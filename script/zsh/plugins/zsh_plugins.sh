#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"

PLUGIN_DIR="$HOME/.zsh/plugins"

section "Installing zsh plugins"

mkdir -p "$PLUGIN_DIR"

# Clone a plugin if missing, or fast-forward it to latest if already present.
# A third arg pins to a specific commit/tag for reproducibility (optional).
#   install_or_update_plugin <name> <repo-url> [ref]
install_or_update_plugin() {
    local name="$1" url="$2" ref="${3:-}"
    local dest="$PLUGIN_DIR/$name"

    if [ ! -d "$dest" ]; then
        step "Installing $name..."
        git clone --depth 1 "$url" "$dest" || { fail "Failed to clone $name"; return 1; }
    else
        step "Updating $name..."
        git -C "$dest" pull --ff-only 2>/dev/null || debug "$name: skipped update (local changes or detached)"
    fi

    if [ -n "$ref" ]; then
        git -C "$dest" fetch --depth 1 origin "$ref" 2>/dev/null
        git -C "$dest" checkout --quiet "$ref" 2>/dev/null || debug "$name: could not pin to $ref"
    fi
}

install_or_update_plugin zsh-autosuggestions     https://github.com/zsh-users/zsh-autosuggestions
install_or_update_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git
