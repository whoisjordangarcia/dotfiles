#!/bin/bash
# Default desktop stream — MAIN stays at its desk-native 4K canvas; prep just
# guarantees index 0 is clean (stray/stale output sweep) before capture.
set -euo pipefail
source "$HOME/.config/sunshine/scripts/lib/sunshine_display.sh"
prep_main_display "$MAIN_DEFAULT_MODE"
