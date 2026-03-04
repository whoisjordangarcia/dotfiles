#!/bin/bash
# Sunshine undo-cmd: restore built-in as main
set -euo pipefail

BD="/opt/homebrew/bin/betterdisplaycli"

# Restore built-in as main
$BD set -nameContains="Built-in" -main=on 2>/dev/null || true
