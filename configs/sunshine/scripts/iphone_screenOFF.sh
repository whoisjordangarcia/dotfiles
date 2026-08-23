#!/bin/bash
# iPhone (19.5:9). Resize the CAPTURED output (MAIN) to a phone-native 19.5:9
# canvas so the stream fills the screen and UI is correctly sized (not 4K-tiny).
set -euo pipefail
source "$HOME/.config/sunshine/scripts/lib/sunshine_display.sh"
prep_main_display "2340x1080@120,0x0,1,bitdepth,10"
