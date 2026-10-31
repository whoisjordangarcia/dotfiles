#!/bin/bash
# Temperature sensor event provider for SketchyBar
# Emits a custom event with CPU/GPU temps every N seconds.
#
# Cost model (M-series): `smctemp -c/-g` is a single cheap read (~10ms). Fan
# RPMs are only exposed via `smctemp -l`, a full ~3000-key SMC dump (~0.9s,
# ~75ms CPU), and only the popup shows them — so temp.lua reads fans itself
# while the popup is open, and this loop never pays for the dump.

EVENT_NAME="${1:-temp_update}"
UPDATE_FREQ="${2:-5.0}"

# Leak guard: kill any other instances of this provider (older reloads).
for pid in $(pgrep -f "temp_sensor/temp_sensor.sh"); do
  if [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ]; then
    kill "$pid" 2>/dev/null
  fi
done

sketchybar --add event "$EVENT_NAME"

# Orphan guard target, resolved once: `kill -0` is a builtin, where a pgrep
# every cycle forks and walks the whole process table (~3.5ms CPU each).
# `sketchybar --reload` keeps the same pid; a real restart relaunches us anyway.
SKETCHYBAR_PID=$(pgrep -x sketchybar | head -1)

while true; do
  # Orphan guard: don't outlive sketchybar.
  kill -0 "$SKETCHYBAR_PID" 2>/dev/null || exit 0

  # -f is fail-soft (returns last valid value if a read fails)
  cpu_temp=$(smctemp -c -n3 -f 2>/dev/null)
  gpu_temp=$(smctemp -g -n3 -f 2>/dev/null)

  cpu_temp="${cpu_temp:-0.0}"
  gpu_temp="${gpu_temp:-0.0}"

  # Truncate to integer for display (printf -v: no subshell fork)
  printf -v cpu_int "%.0f" "$cpu_temp" 2>/dev/null || cpu_int=0

  sketchybar --trigger "$EVENT_NAME" \
    cpu_temp="$cpu_temp" \
    gpu_temp="$gpu_temp" \
    cpu_temp_int="$cpu_int"

  sleep "$UPDATE_FREQ"
done
