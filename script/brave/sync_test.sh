#!/bin/bash
#===============================================================================
# sync_test.sh — assertion tests for extract_extensions.py against a fixture.
# Builds a throwaway Brave dir with a mix of extension kinds and asserts the
# extractor keeps ONLY user-installed Web Store extensions (unioned, deduped).
#===============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
FIXTURE=$(mktemp -d)
trap 'rm -rf "$FIXTURE"' EXIT

# 32-char ids (content is arbitrary, only length + fields matter)
WEBSTORE_A="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"  # kept
WEBSTORE_B="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"  # kept (only in Profile 1)
MANAGED="cccccccccccccccccccccccccccccccc"     # location 4 -> dropped
COMPONENT="dddddddddddddddddddddddddddddddd"   # location 5 -> dropped
DISABLED="eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"     # state 0 -> dropped
THEME="ffffffffffffffffffffffffffffffff"       # theme  -> dropped

mkdir -p "$FIXTURE/Default" "$FIXTURE/Profile 1"

cat >"$FIXTURE/Default/Secure Preferences" <<JSON
{"extensions":{"settings":{
  "$WEBSTORE_A":{"location":1,"from_webstore":true,"manifest":{"name":"Alpha"}},
  "$MANAGED":{"location":7,"from_webstore":true,"manifest":{"name":"ManagedExt"}},
  "$COMPONENT":{"location":5,"from_webstore":false,"manifest":{"name":"Brave"}},
  "$DISABLED":{"location":1,"from_webstore":true,"state":0,"manifest":{"name":"OffExt"}},
  "$THEME":{"location":1,"from_webstore":true,"manifest":{"name":"DarkTheme","theme":{}}}
}}}
JSON

# Profile 1 repeats Alpha (must dedupe) and adds Beta at location 6 — the state
# our own soft-installer leaves extensions in; it MUST still be captured.
cat >"$FIXTURE/Profile 1/Secure Preferences" <<JSON
{"extensions":{"settings":{
  "$WEBSTORE_A":{"location":1,"from_webstore":true,"manifest":{"name":"Alpha"}},
  "$WEBSTORE_B":{"location":6,"from_webstore":true,"manifest":{"name":"Beta"}}
}}}
JSON

got=$(python3 "$SCRIPT_DIR/extract_extensions.py" "$FIXTURE")
want=$(printf '%s  # Alpha\n%s  # Beta' "$WEBSTORE_A" "$WEBSTORE_B")

if [ "$got" = "$want" ]; then
	echo "✓ keeps webstore, drops managed/component/disabled/theme, unions+dedupes+sorts"
	echo "All 1 tests passed"
else
	echo "✗ extractor output mismatch"
	echo "--- got ---"; echo "$got"
	echo "--- want ---"; echo "$want"
	exit 1
fi
