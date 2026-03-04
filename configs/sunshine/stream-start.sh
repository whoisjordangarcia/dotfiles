#!/bin/bash
# Sunshine prep-cmd: connect virtual display and set as main
set -euo pipefail

BD="/opt/homebrew/bin/betterdisplaycli"
TAG_VIRTUAL=3

# Connect the virtual display (no-op if already connected)
$BD set -tagID=$TAG_VIRTUAL -connected=on 2>/dev/null || true
sleep 1

# Set resolution and main
$BD set -tagID=$TAG_VIRTUAL -resolution=1920x1080 -hiDPI=on 2>/dev/null || true
$BD set -tagID=$TAG_VIRTUAL -main=on 2>/dev/null || true
