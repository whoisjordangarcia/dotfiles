#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"

# Check if 1Password CLI is installed
if ! command -v op &>/dev/null; then
	info "1Password CLI not installed — skipping (install via Homebrew: 1password-cli)"
	return 0 2>/dev/null || exit 0
fi

# Check if CLI is already authenticated (op whoami confirms active session, not just account list)
if op whoami &>/dev/null 2>&1; then
	success "1Password CLI already connected"
	return 0 2>/dev/null || exit 0
fi

# Account registered but not signed in — sign in now
if op account list 2>/dev/null | grep -q "@"; then
	info "1Password account found — signing in..."
	eval "$(op signin)"
	if op whoami &>/dev/null 2>&1; then
		success "1Password CLI signed in!"
	else
		info "Sign-in failed — secrets injection will be skipped."
	fi
	return 0 2>/dev/null || exit 0
fi

# No account at all — prompt user to enable desktop app integration
echo ""
info "1Password CLI needs to be connected to the 1Password desktop app."
info "This is the recommended method — no manual sign-in needed each session."
info ""
info "Steps:"
info "  1. Open 1Password app"
info "  2. Go to Settings → Developer"
info "  3. Enable 'Integrate with 1Password CLI'"
echo ""
prompt "Press Enter once you've enabled the integration (or Ctrl+C to skip)..."
read -r || true

# Verify it worked
if op whoami &>/dev/null 2>&1; then
	success "1Password CLI connected!"
else
	info "1Password CLI not connected — secrets injection will be skipped during zsh setup."
	info "To fix later: enable the desktop integration, then re-run: ./script/zsh/setup.sh"
fi
