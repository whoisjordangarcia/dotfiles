#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"

# No brew formula or prebuilt binaries — built via cargo. Deps (rust, libmpv)
# come from Brewfile.base on mac; on Linux install rust + mpv via the distro.
if command -v sonic-tui &>/dev/null || [[ -x "$HOME/.cargo/bin/sonic-tui" ]]; then
  info "sonic-tui already installed. Skipping build."
else
  info "Installing sonic-tui via cargo (this builds from source)..."
  # macOS: rustc doesn't search Homebrew's lib dir, so linking -lmpv fails without this
  [[ "$OSTYPE" == darwin* ]] && export LIBRARY_PATH="/opt/homebrew/lib:${LIBRARY_PATH:-}"
  # Pin the release tag (HEAD doesn't always compile), --locked to use the
  # repo's Cargo.lock, and apply our fixes: manual plays froze the UI ~5s on
  # an inline lrclib.net lyrics/cover fetch (now via background prefetcher),
  # and end-of-track detection is event-driven (EndFile) instead of polling
  # idle-active, which raced against async stream opens. Drop when upstream.
  BUILD_DIR=$(mktemp -d)
  git clone --quiet --depth 1 --branch v0.6.0 https://codeberg.org/thelinuxcast/sonic-tui "$BUILD_DIR"
  git -C "$BUILD_DIR" apply "$SCRIPT_DIR/../../configs/sonic-tui/fixes.patch"
  cargo install --locked --path "$BUILD_DIR"
  rm -rf "$BUILD_DIR"
  success "sonic-tui installed to ~/.cargo/bin"
fi

# The config holds the Navidrome password, so it is COPIED (not symlinked)
# from the template and the real file never enters this public repo.
CONFIG="$HOME/.config/sonic-tui/config.yaml"
if [[ -f "$CONFIG" ]]; then
  debug "sonic-tui config already present. Skipping."
else
  mkdir -p "$(dirname "$CONFIG")"
  cp "$SCRIPT_DIR/../../configs/sonic-tui/config.template.yaml" "$CONFIG"
  chmod 600 "$CONFIG" # holds the Navidrome password
  warn "Created $CONFIG from template — fill in your Navidrome URL/username/password"
fi

# sonic-tui hardcodes dirs::config_dir() — Application Support on macOS, no
# XDG/--config override — so symlink it back to ~/.config to keep one location.
if [[ "$OSTYPE" == darwin* ]]; then
  AS_DIR="$HOME/Library/Application Support/sonic-tui"
  [[ -e "$AS_DIR" && ! -L "$AS_DIR" ]] && { warn "$AS_DIR exists as a real dir — leaving it alone"; } ||
    ln -sfn "$HOME/.config/sonic-tui" "$AS_DIR"
fi
