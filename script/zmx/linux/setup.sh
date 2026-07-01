#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_DIR/../../common/log.sh"

# zmx is not packaged in pacman/apt/dnf, so install the prebuilt release binary
# into ~/.local/bin (already on PATH via configs/zshrc/.zshrc). macOS installs
# zmx through Homebrew instead — see script/apps/mac/Brewfile.base.
#
# The release assets embed the version and there is no "latest/download" alias,
# so resolve the newest tag from the GitHub API and fall back to a pinned
# version only when the API is unreachable (e.g. offline LXC provisioning).

REPO="neurosnap/zmx"
INSTALL_DIR="$HOME/.local/bin"
PINNED_FALLBACK="0.6.0"

# Map machine architecture to the release asset naming.
case "$(uname -m)" in
	x86_64 | amd64) ARCH="x86_64" ;;
	aarch64 | arm64) ARCH="aarch64" ;;
	*)
		error "zmx: unsupported architecture $(uname -m)"
		exit 1
		;;
esac

# Resolve the latest published version (strip a leading "v"); fall back if offline.
VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null |
	sed -nE 's/.*"tag_name":[[:space:]]*"v?([^"]+)".*/\1/p' | head -n1)
VERSION="${VERSION:-$PINNED_FALLBACK}"

# Skip the download when the installed binary is already the target version.
if command -v zmx &>/dev/null; then
	CURRENT=$(zmx version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)
	if [[ "$CURRENT" == "$VERSION" ]]; then
		info "zmx already up to date (v$VERSION)"
		return 0 2>/dev/null || exit 0
	fi
fi

ASSET="zmx-${VERSION}-linux-${ARCH}.tar.gz"
BASE_URL="https://github.com/$REPO/releases/download/v${VERSION}"

info "Installing zmx v$VERSION ($ARCH)..."
TMP=$(mktemp -d)

curl -fsSL "$BASE_URL/$ASSET" -o "$TMP/$ASSET"

# Verify against the .sha256 sidecar when present. Its second column is a build
# cache path rather than the local filename, so compare only the hash field
# instead of relying on `sha256sum -c`.
if curl -fsSL "$BASE_URL/$ASSET.sha256" -o "$TMP/$ASSET.sha256" 2>/dev/null; then
	EXPECTED=$(awk '{print $1}' "$TMP/$ASSET.sha256")
	ACTUAL=$(sha256sum "$TMP/$ASSET" | awk '{print $1}')
	if [[ "$EXPECTED" != "$ACTUAL" ]]; then
		rm -rf "$TMP"
		error "zmx: checksum mismatch (expected $EXPECTED, got $ACTUAL)"
		exit 1
	fi
	success "Checksum verified"
fi

# The tarball contains a single `zmx` binary at its root.
tar -xzf "$TMP/$ASSET" -C "$TMP"
mkdir -p "$INSTALL_DIR"
install -m 0755 "$TMP/zmx" "$INSTALL_DIR/zmx"
rm -rf "$TMP"

success "zmx v$VERSION installed to $INSTALL_DIR/zmx"
