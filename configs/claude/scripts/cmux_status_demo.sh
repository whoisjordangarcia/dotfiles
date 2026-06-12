#!/bin/bash
# cmux_status_demo.sh — visual demo of the cmux sidebar pill + progress bar.
# Drives the REAL cmux against the current workspace so you can eyeball each
# rendering. No-ops with a message when not running inside cmux.
# Run: bash configs/claude/scripts/cmux_status_demo.sh
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
CLI="/Applications/cmux.app/Contents/Resources/bin/cmux"
WS="${CMUX_WORKSPACE_ID:-}"
PAUSE="${DEMO_PAUSE:-1.5}"

if [ ! -x "$CLI" ] || [ "$($CLI ping 2>/dev/null)" != "PONG" ] || [ -z "$WS" ]; then
  echo "Not inside a live cmux workspace — nothing to demo."
  exit 0
fi

say() { printf "\n\033[38;5;141m▶ %s\033[0m\n" "$1"; }

say "review pill: APPROVED  (look for '✓ Approved #42' in the sidebar)"
"$CLI" set-status review "✓ Approved #42" --icon checkmark.seal.fill \
  --color "#3FB950" --priority 20 --workspace "$WS"; sleep "$PAUSE"

say "review pill: cleared  (CHANGES_REQUESTED / no PR — pill disappears)"
"$CLI" clear-status review --workspace "$WS"; sleep "$PAUSE"

say "progress bar: advancing 20% -> 100%"
for f in 0.20 0.40 0.60 0.80 1.00; do
  "$CLI" set-progress "$f" --label "step @ ${f}" --workspace "$WS"; sleep "$PAUSE"
done

say "progress bar: cleared  (empty todo list / fresh session)"
"$CLI" clear-progress --workspace "$WS"

say "done — sidebar restored to idle"
