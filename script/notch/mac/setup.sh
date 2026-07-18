#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"

# macOS-only: MediaNotch is a top-center overlay window (Dynamic-Island style)
# that shows mpd/mpc now-playing while a track is loaded.
if [[ "$OSTYPE" != darwin* ]]; then
	info "MediaNotch is macOS-only; skipping."
	exit 0
fi

if ! command -v swiftc &>/dev/null; then
	info "swiftc not found (install Xcode Command Line Tools); skipping MediaNotch build."
	exit 0
fi

SRC="$SCRIPT_DIR/../../../configs/notch/MediaNotch.swift"
PLIST="$SCRIPT_DIR/../../../configs/notch/medianotch-Info.plist"
APP="$HOME/Applications/MediaNotch.app"
BIN="$APP/Contents/MacOS/MediaNotch"
SHIM="$HOME/.local/bin/media-notch"

# Rebuild only when the source or plist is newer than the built app.
if [[ ! -x "$BIN" || "$SRC" -nt "$BIN" || "$PLIST" -nt "$APP/Contents/Info.plist" ]]; then
	step "Building MediaNotch.app..."
	mkdir -p "$APP/Contents/MacOS"
	cp "$PLIST" "$APP/Contents/Info.plist"
	swiftc -O "$SRC" -o "$BIN"
	success "MediaNotch.app built at $APP"
else
	debug "MediaNotch.app already built and up to date. Skipping."
fi

# ~/.local/bin/media-notch execs into the bundle (same shim pattern as bioprompt).
mkdir -p "$(dirname "$SHIM")"
cat >"$SHIM" <<EOF
#!/bin/bash
exec "$BIN" "\$@"
EOF
chmod +x "$SHIM"
success "shim: $SHIM (run 'media-notch' to launch; 'pkill -x MediaNotch' to quit)"
