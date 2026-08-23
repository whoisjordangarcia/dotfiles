#!/bin/bash
# iPad (2560x1440). Resize the CAPTURED output (MAIN) to the client-native
# canvas so the stream fills the screen with correctly sized UI.
set -euo pipefail
source "$HOME/.config/sunshine/scripts/lib/sunshine_display.sh"
prep_main_display "2560x1440@120,0x0,1.5,bitdepth,10"
