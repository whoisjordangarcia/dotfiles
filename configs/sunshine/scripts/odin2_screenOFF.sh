#!/bin/bash
# Odin 2 / Odin 2 Portal (16:9 1080p). Resize captured MAIN to device-native
# 1920x1080 so the panel fills edge-to-edge with correctly sized UI.
set -euo pipefail
source "$HOME/.config/sunshine/scripts/lib/sunshine_display.sh"
prep_main_display "1920x1080@120,0x0,1,bitdepth,10"
