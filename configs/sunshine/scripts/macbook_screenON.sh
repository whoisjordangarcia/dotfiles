#!/bin/bash
# Undo macbook_screenOFF.sh: drop mirror, restore HDMI config and sensitivity.
set -euo pipefail
source "$HOME/.config/sunshine/scripts/lib/sunshine_display.sh"
ensure_hyprland_env

LOG_TAG="sunshine-mbp-undo"
SENS_FILE="/tmp/sunshine-mbp-sensitivity"
HDMI_FILE="/tmp/sunshine-mbp-hdmi"
STREAM_OUTPUT="HDMI-A-1"

restore_sens=$(cat "$SENS_FILE" 2>/dev/null || echo "0.2")
restore_hdmi=$(cat "$HDMI_FILE" 2>/dev/null || echo "preferred,auto,1")

hyprctl keyword monitor "$STREAM_OUTPUT,$restore_hdmi" >/dev/null
hyprctl keyword input:sensitivity "$restore_sens"

logger -t "$LOG_TAG" "restored sens=$restore_sens hdmi=$restore_hdmi"
rm -f "$SENS_FILE" "$HDMI_FILE"
