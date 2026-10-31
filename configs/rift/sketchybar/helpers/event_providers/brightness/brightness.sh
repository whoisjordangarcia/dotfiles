#!/bin/bash
# Brightness event provider for SketchyBar
# Reads display brightness via the DisplayServices private framework.
# The Swift reader is compiled once into bin/ (~5ms per read after that);
# falls back to `swift -e` interpretation only if compilation fails.

EVENT_NAME="${1:-brightness_update}"
UPDATE_FREQ="${2:-5.0}"

HELPER_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
READER_BIN="$HELPER_DIR/bin/brightness_reader"
READER_SRC="$HELPER_DIR/brightness_reader.swift"

# Leak guard: kill any other instances of this provider (older reloads).
for pid in $(pgrep -f "brightness/brightness.sh"); do
  if [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ]; then
    kill "$pid" 2>/dev/null
  fi
done

# Compile the reader once if missing or older than its source.
if [ ! -x "$READER_BIN" ] || [ "$READER_SRC" -nt "$READER_BIN" ]; then
  mkdir -p "$HELPER_DIR/bin"
  swiftc -O -o "$READER_BIN" "$READER_SRC" 2>/dev/null
fi

read_brightness() {
  if [ -x "$READER_BIN" ]; then
    "$READER_BIN" 2>/dev/null
  else
    swift "$READER_SRC" 2>/dev/null
  fi
}

sketchybar --add event "$EVENT_NAME"

# Orphan guard target, resolved once (see temp_sensor.sh): `kill -0` is a
# builtin, a per-cycle pgrep is a fork plus a process-table walk.
SKETCHYBAR_PID=$(pgrep -x sketchybar | head -1)

while true; do
  # Orphan guard: don't outlive sketchybar.
  kill -0 "$SKETCHYBAR_PID" 2>/dev/null || exit 0

  brightness=$(read_brightness)
  brightness="${brightness:-0}"

  sketchybar --trigger "$EVENT_NAME" brightness="$brightness"

  sleep "$UPDATE_FREQ"
done
