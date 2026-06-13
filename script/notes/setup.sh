#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"

NOTES_DIR="$HOME/dev/notes"
NOTES_REPO="git@github.com:whoisjordangarcia/notes.git"

if [ -d "$NOTES_DIR" ]; then
    info "Notes repo already exists at $NOTES_DIR, skipping clone"
else
    info "Cloning notes repo to $NOTES_DIR..."
    git clone "$NOTES_REPO" "$NOTES_DIR"
    success "Cloned notes repo to $NOTES_DIR"
fi

# Enable the official Obsidian CLI.
#
# The `obsidian` binary ships inside the Obsidian cask (installed via
# Brewfile.base), but the CLI is gated behind an in-app setting
# (Settings > General > Advanced > "Command line interface"). That setting is
# just the `"cli": true` flag in Obsidian's global config, so we can flip it
# here instead of clicking through the GUI. Pairs with the `notes-cli` skill.
enable_obsidian_cli() {
    # Config path differs by platform.
    local config
    case "$OSTYPE" in
    darwin*) config="$HOME/Library/Application Support/obsidian/obsidian.json" ;;
    linux*) config="$HOME/.config/obsidian/obsidian.json" ;;
    *)
        debug "Unknown platform ($OSTYPE) — skipping Obsidian CLI enable."
        return 0
        ;;
    esac

    if ! command -v jq &>/dev/null; then
        warn "jq not found — skipping Obsidian CLI enable (install jq, then re-run)."
        return 0
    fi

    # Already on? Nothing to do.
    if [[ -f "$config" ]] && [[ "$(jq -r '.cli // false' "$config" 2>/dev/null)" == "true" ]]; then
        debug "Obsidian CLI already enabled. Skipping."
        return 0
    fi

    mkdir -p "$(dirname "$config")"

    if [[ -f "$config" ]]; then
        # Merge the flag into the existing config (preserves vault registrations).
        local tmp
        tmp="$(mktemp)"
        jq '.cli = true' "$config" >"$tmp" && mv "$tmp" "$config"
    else
        # No config yet (Obsidian never launched) — seed it; Obsidian merges in
        # its vault list on first launch and keeps this flag.
        echo '{"cli":true}' >"$config"
    fi

    success "Obsidian CLI enabled (cli=true in $config)."
    info "Restart Obsidian (or run it once) for the change to take effect."
}

enable_obsidian_cli
