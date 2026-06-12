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

# No account at all — walk through enabling the desktop app integration

# The desktop app is required for CLI integration; install if missing
# (normally handled by Brewfile.base, but be defensive for partial installs)
if [ ! -d "/Applications/1Password.app" ]; then
	info "1Password app not found. Installing via Homebrew..."
	brew install --cask 1password
fi

echo ""
info "1Password CLI needs to be connected to the 1Password desktop app."
info "This is the recommended method — no manual sign-in needed each session."
info ""
info "Steps (the app is opening now):"
info "  1. Sign in to the 1Password app (if you haven't yet)"
info "  2. Go to Settings → Developer"
info "  3. Enable 'Integrate with 1Password CLI'"
echo ""
open -a "1Password" 2>/dev/null || true

# Re-check until connected, or the user explicitly skips
while true; do
	prompt "Press Enter once you've enabled the integration (or type 's' to skip): "
	read -r answer || answer="s"
	if [[ "$answer" == [sS] ]]; then
		info "Skipped — secrets injection will be skipped during zsh setup."
		info "To fix later: enable the desktop integration, then re-run: ./script/zsh/setup.sh"
		break
	fi
	if op whoami &>/dev/null 2>&1; then
		success "1Password CLI connected!"
		break
	fi
	warn "Not connected yet — make sure 'Integrate with 1Password CLI' is enabled in Settings → Developer."
done
