#!/bin/bash
# Stream HDMI-A-1 (dummy plug) to a 15" MacBook Pro.
# When DP-1 is active, mirror HDMI to it so the MBP shows the desk view.
# When DP-1 is absent (away from desk), HDMI streams standalone.
set -euo pipefail
source "$HOME/.config/sunshine/scripts/lib/sunshine_display.sh"
ensure_hyprland_env

LOG_TAG="sunshine-mbp"
SENS_FILE="/tmp/sunshine-mbp-sensitivity"
HDMI_FILE="/tmp/sunshine-mbp-hdmi"
STREAM_OUTPUT="HDMI-A-1"
DESK_OUTPUT="DP-1"

cur_sens=$(hyprctl -j getoption input:sensitivity | jq -r '.float')
echo "$cur_sens" > "$SENS_FILE"

# Build a "WxH@rr,XxY,scale" mode string for the dummy-plug output. Refresh
# rate is rounded to 2 decimals to match Hyprland's mode notation.
hdmi_cfg=$(hyprctl -j monitors | jq -r --arg n "$STREAM_OUTPUT" '
    .[] | select(.name==$n)
    | "\(.width)x\(.height)@\((.refreshRate*100|round)/100),\(.x)x\(.y),\(.scale)"')
echo "$hdmi_cfg" > "$HDMI_FILE"

dp_active=$(hyprctl -j monitors | jq -r --arg d "$DESK_OUTPUT" 'any(.[]; .name==$d)')

logger -t "$LOG_TAG" "saved sens=$cur_sens hdmi=$hdmi_cfg dp_active=$dp_active"

hyprctl dispatch dpms on "$STREAM_OUTPUT" >/dev/null 2>&1 || true

if [ "$dp_active" = "true" ]; then
    hyprctl keyword monitor "$STREAM_OUTPUT,$hdmi_cfg,mirror,$DESK_OUTPUT" >/dev/null
    logger -t "$LOG_TAG" "mirrored $STREAM_OUTPUT -> $DESK_OUTPUT"
else
    hyprctl dispatch focusmonitor "$STREAM_OUTPUT" >/dev/null 2>&1 || true
fi

hyprctl keyword input:sensitivity -0.7
