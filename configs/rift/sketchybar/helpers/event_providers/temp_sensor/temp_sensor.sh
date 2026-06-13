#!/bin/bash
# Temperature & Fan sensor event provider for SketchyBar
# Emits a custom event with temp and fan data every N seconds.
#
# Cost model (M-series): `smctemp -c/-g` is a single cheap read (~10ms), but
# fan RPMs are only exposed via `smctemp -l`, a full ~3000-key SMC dump that
# takes ~2.7s — so fans are refreshed every FAN_EVERY cycles, not every cycle.

EVENT_NAME="${1:-temp_update}"
UPDATE_FREQ="${2:-5.0}"
FAN_EVERY=6

# Leak guard: kill any other instances of this provider (older reloads).
for pid in $(pgrep -f "temp_sensor/temp_sensor.sh"); do
  if [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ]; then
    kill "$pid" 2>/dev/null
  fi
done

sketchybar --add event "$EVENT_NAME"

fan0=0
fan1=0
cycle=0

# Fan count is fixed per machine; read it once (FNum key). Mac mini = 1,
# most MacBook Pros = 2. Drives how many fan rows the popup draws.
# `[ui8 ]` splits into two fields, so the value is $4 (same as the F0Ac parse).
fan_count=$(smctemp -l 2>/dev/null | awk '/^[[:space:]]*FNum/ {printf "%.0f", $4; exit}')
fan_count="${fan_count:-0}"

while true; do
  # Orphan guard: don't outlive sketchybar.
  pgrep -qx sketchybar || exit 0

  # -f is fail-soft (returns last valid value if a read fails)
  cpu_temp=$(smctemp -c -n3 -f 2>/dev/null)
  gpu_temp=$(smctemp -g -n3 -f 2>/dev/null)

  if [ $((cycle % FAN_EVERY)) -eq 0 ]; then
    # Dump line format: `F0Ac  [flt ]  2310.7 (bytes: ...)` — `[flt ]` splits
    # into two fields, so the RPM value is $4 (not $3).
    fans=$(smctemp -l 2>/dev/null | awk '/F0Ac/ {f0=$4} /F1Ac/ {f1=$4} END {printf "%.0f %.0f", f0, f1}')
    fan0="${fans% *}"
    fan1="${fans#* }"
  fi
  cycle=$((cycle + 1))

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
    fan_count="$fan_count" \
    fan0_rpm="$fan0" \
    fan1_rpm="$fan1"

  sleep "$UPDATE_FREQ"
done
