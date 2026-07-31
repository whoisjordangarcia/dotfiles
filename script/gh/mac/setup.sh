#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"
source "$SCRIPT_DIR/../../common/dot_env.sh"
dot_export_env

if ! command -v gh &>/dev/null; then
    info "gh CLI not found — install via Homebrew first"
    exit 0
fi

if gh auth status &>/dev/null 2>&1; then
    debug "gh CLI already authenticated, skipping"
else
    step "Logging into GitHub CLI..."
    gh auth login --web --git-protocol ssh
    success "GitHub CLI authenticated"
fi

# gh-stack (stacked PRs) — work only
if [[ "$DOT_ENV" == "work" ]]; then
    if gh extension list 2>/dev/null | grep -q 'github/gh-stack'; then
        debug "gh-stack already installed, skipping"
    else
        step "Installing gh-stack extension..."
        gh extension install github/gh-stack && success "gh-stack installed"
    fi
fi
