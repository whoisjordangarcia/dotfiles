#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"

if ! command -v gh &>/dev/null; then
    info "gh CLI not found — install via Homebrew first"
    return 0
fi

if gh auth status &>/dev/null 2>&1; then
    debug "gh CLI already authenticated, skipping"
else
    step "Logging into GitHub CLI..."
    gh auth login --web --git-protocol ssh
    success "GitHub CLI authenticated"
fi
