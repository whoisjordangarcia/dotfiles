#!/bin/bash
#===============================================================================
# flags_test.sh — assertion tests for apply_flags.py. Verifies the union is
# additive (keeps existing flags) and deduped/sorted, and comments are ignored.
#===============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
FIX=$(mktemp -d)
trap 'rm -rf "$FIX"' EXIT

# Existing Local State already has one user-enabled flag plus other keys to keep.
echo '{"browser":{"enabled_labs_experiments":["mine@1"],"other":true},"keep":9}' >"$FIX/Local State"
printf '# a comment\nhttps-by-default@2\nmine@1\n' >"$FIX/flags.txt"

python3 "$SCRIPT_DIR/apply_flags.py" "$FIX" "$FIX/flags.txt" >/dev/null

fails=0
assert() {
	if python3 -c "import json,sys; F='$FIX'; sys.exit(0 if ($2) else 1)"; then echo "✓ $1"
	else echo "✗ $1"; fails=$((fails + 1)); fi
}

assert "unions config with existing, deduped + sorted" \
	"json.load(open(F+'/Local State'))['browser']['enabled_labs_experiments'] == ['https-by-default@2','mine@1']"
assert "pre-existing user flag preserved (additive)" \
	"'mine@1' in json.load(open(F+'/Local State'))['browser']['enabled_labs_experiments']"
assert "unrelated Local State keys untouched" \
	"json.load(open(F+'/Local State'))['keep'] == 9 and json.load(open(F+'/Local State'))['browser']['other'] == True"

if [ "$fails" -eq 0 ]; then echo "All 3 tests passed"; else echo "$fails failed"; exit 1; fi
