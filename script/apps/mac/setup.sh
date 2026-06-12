#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"

# Install Xcode CLI tools
if xcode-select -p &>/dev/null; then
  debug "Xcode command line tools already installed. Skipping."
else
  info "Installing Xcode command line tools..."
  xcode-select --install
  # xcode-select --install opens a GUI installer and returns immediately —
  # wait for it to finish, otherwise the Homebrew install below races it.
  info "Waiting for Xcode command line tools installer to complete..."
  until xcode-select -p &>/dev/null; do
    sleep 5
  done
  success "Xcode command line tools installed."
fi

# Check if Homebrew is installed
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>$HOME/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Ask for sudo upfront and keep the session alive for the duration of the script
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

brew analytics off

# Install packages
info "Installing Brewfile packages..."
brew bundle --file="$SCRIPT_DIR/Brewfile.base"

# Machine-specific overlay (gitignored) — packages that belong to this machine
# only. Also keeps `brew bundle cleanup` below from flagging them for removal.
BREWFILE_LOCAL="$SCRIPT_DIR/Brewfile.local"
if [[ -f "$BREWFILE_LOCAL" ]]; then
  info "Installing Brewfile.local packages..."
  brew bundle --file="$BREWFILE_LOCAL"
fi

# Keep packages fresh in the background (tap: homebrew/autoupdate)
if ! brew autoupdate status 2>/dev/null | grep -q 'and running'; then
  step "Enabling brew autoupdate (daily upgrade + cleanup)..."
  brew autoupdate start 86400 --upgrade --cleanup
fi

# Optionally remove packages that are no longer in the Brewfile(s)
echo ""
prompt "Remove brew packages not listed in the Brewfile? [y/N]: "
read -r cleanup_choice || cleanup_choice=""
if [[ "$cleanup_choice" =~ ^[Yy]$ ]]; then
  # cleanup only accepts a single manifest — merge base + local
  cleanup_manifest=$(mktemp)
  cat "$SCRIPT_DIR/Brewfile.base" >"$cleanup_manifest"
  [[ -f "$BREWFILE_LOCAL" ]] && cat "$BREWFILE_LOCAL" >>"$cleanup_manifest"
  brew bundle cleanup --file="$cleanup_manifest" --force
  rm -f "$cleanup_manifest"
  success "Brew cleanup complete."
else
  debug "Skipping brew cleanup."
fi
