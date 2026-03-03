#!/bin/bash
# Temperature & Fan sensor event provider for SketchyBar
# Uses smctemp to read Apple Silicon CPU/GPU temps and fan RPMs
# Emits a custom event with temp and fan data every N seconds

EVENT_NAME="${1:-temp_update}"
UPDATE_FREQ="${2:-5.0}"

# Add the event
sketchybar --add event "$EVENT_NAME"

while true; do
  cpu_temp=$(smctemp -c 2>/dev/null | head -1)
  gpu_temp=$(smctemp -g 2>/dev/null | head -1)

  # Read fan speeds from SMC keys (F0Ac = Fan 0 actual, F1Ac = Fan 1 actual)
  smc_dump=$(smctemp -l 2>/dev/null)
  fan0=$(echo "$smc_dump" | awk '/F0Ac/ {printf "%.0f", $3}')
  fan1=$(echo "$smc_dump" | awk '/F1Ac/ {printf "%.0f", $3}')

  # Fallback if values are empty
  cpu_temp="${cpu_temp:-0.0}"
  gpu_temp="${gpu_temp:-0.0}"
  fan0="${fan0:-0}"
  fan1="${fan1:-0}"

  # Truncate to integer for display
  cpu_int=$(printf "%.0f" "$cpu_temp" 2>/dev/null || echo "0")

  sketchybar --trigger "$EVENT_NAME" \
    cpu_temp="$cpu_temp" \
    gpu_temp="$gpu_temp" \
    cpu_temp_int="$cpu_int" \
    fan0_rpm="$fan0" \
    fan1_rpm="$fan1"

  sleep "$UPDATE_FREQ"
done
