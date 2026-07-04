#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
THEMES_DIR="$SCRIPT_DIR/themes"
CURRENT=$(readlink "$THEMES_DIR/active" 2>/dev/null || echo "unknown")

if [ $# -eq 0 ]; then
    echo "Current theme: $CURRENT"
    echo "Available themes:"
    for theme in "$THEMES_DIR"/*/; do
        name=$(basename "$theme")
        [ "$name" = "active" ] && continue
        marker=$( [ "$name" = "$CURRENT" ] && echo " (active)" || echo "" )
        echo "  - $name$marker"
    done
    exit 0
fi

THEME=$1
if [ ! -d "$THEMES_DIR/$THEME" ]; then
    echo "Theme '$THEME' not found."
    exit 1
fi

ln -sfn "$THEME" "$THEMES_DIR/active"
# --reload re-runs the config in place (theme resolves via package.path at
# load time) — much faster than bouncing the brew service
sketchybar --reload
echo "Switched to theme: $THEME"
