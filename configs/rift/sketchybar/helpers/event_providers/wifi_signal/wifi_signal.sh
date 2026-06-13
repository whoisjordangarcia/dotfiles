#!/bin/bash
# Wi-Fi signal event provider for SketchyBar
# Emits rssi (dBm) + ssid every N seconds via a compiled CoreWLAN reader (~5ms).

EVENT_NAME="${1:-wifi_signal_update}"
UPDATE_FREQ="${2:-10.0}"

HELPER_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
READER_BIN="$HELPER_DIR/bin/wifi_reader"
READER_SRC="$HELPER_DIR/wifi_reader.swift"

# Leak guard: kill any other instances of this provider (older reloads).
for pid in $(pgrep -f "wifi_signal/wifi_signal.sh"); do
  if [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ]; then
    kill "$pid" 2>/dev/null
  fi
done

# Compile the reader once if missing or older than its source.
if [ ! -x "$READER_BIN" ] || [ "$READER_SRC" -nt "$READER_BIN" ]; then
  mkdir -p "$HELPER_DIR/bin"
  swiftc -O -o "$READER_BIN" "$READER_SRC" 2>/dev/null
fi

read_signal() {
  if [ -x "$READER_BIN" ]; then
    "$READER_BIN" 2>/dev/null
  else
    swift "$READER_SRC" 2>/dev/null
  fi
}

sketchybar --add event "$EVENT_NAME"

while true; do
  # Orphan guard: don't outlive sketchybar.
  pgrep -qx sketchybar || exit 0

  out=$(read_signal)
  out="${out:-0|}"
  rssi="${out%%|*}"
  ssid="${out#*|}"

  sketchybar --trigger "$EVENT_NAME" rssi="$rssi" ssid="$ssid"

  sleep "$UPDATE_FREQ"
done
