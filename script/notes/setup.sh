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
