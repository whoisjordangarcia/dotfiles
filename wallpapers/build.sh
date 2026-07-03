#!/bin/bash
# Generate dark-mode-friendly variants of wallpapers in this directory.
# Source images stay committed; *-dark.jpg outputs are gitignored.
#
# Tunables (env vars):
#   DARK_TINT       hex color blended over the image (default #0b0e14)
#   DARK_TINT_PCT   blend strength 0-100  (default 30)
#   DARK_BRIGHTNESS modulate brightness % (default 65)
#   DARK_SATURATION modulate saturation % (default 75)

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_DIR/../script/common/log.sh"

command -v magick >/dev/null || fail "ImageMagick (magick) is required"

TINT="${DARK_TINT:-#0b0e14}"
TINT_PCT="${DARK_TINT_PCT:-30}"
BRIGHT="${DARK_BRIGHTNESS:-65}"
SAT="${DARK_SATURATION:-75}"

shopt -s nullglob
count=0
for src in "$SCRIPT_DIR"/*.{jpg,jpeg,png}; do
    base="${src##*/}"
    name="${base%.*}"
    [[ "$name" == *-dark ]] && continue

    out="$SCRIPT_DIR/${name}-dark.jpg"
    step "Building ${name}-dark.jpg"
    magick "$src" \
        -modulate "${BRIGHT},${SAT},100" \
        -fill "$TINT" -colorize "${TINT_PCT}%" \
        -quality 92 \
        "$out"
    count=$((count + 1))
done

success "Generated $count dark variant(s)"
