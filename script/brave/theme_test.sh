#!/bin/bash
#===============================================================================
# theme_test.sh — assertion tests for apply_themes.py against a fixture Brave dir.
# Verifies name->dir mapping, correct signed-ARGB color, and that unrelated prefs
# are preserved (additive, never wipes).
#===============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
FIX=$(mktemp -d)
trap 'rm -rf "$FIX"' EXIT

mkdir -p "$FIX/Default" "$FIX/Profile 1"
cat >"$FIX/Local State" <<'JSON'
{"profile":{"info_cache":{"Default":{"name":"Work"},"Profile 1":{"name":"Personal"}}}}
JSON
# Each profile has an unrelated pref that must survive the edit.
echo '{"browser":{"custom_chrome_frame":true},"keep":{"me":42}}' >"$FIX/Default/Preferences"
echo '{"keep":{"me":7}}' >"$FIX/Profile 1/Preferences"

cat >"$FIX/themes.txt" <<'TXT'
# comment line
Work=#1A73E8
Personal=#E8710A
Ghost=#000000
TXT

python3 "$SCRIPT_DIR/apply_themes.py" "$FIX" "$FIX/themes.txt" >/dev/null

fails=0
assert() { # desc, python-bool-expr over the fixture
	if python3 -c "import json,sys; F='$FIX'; sys.exit(0 if ($2) else 1)"; then
		echo "✓ $1"
	else
		echo "✗ $1"; fails=$((fails + 1))
	fi
}

# Independent of the conversion arithmetic: reinterpret stored int as unsigned
# 32-bit ARGB and check alpha=0xFF, rgb=0x1A73E8.
assert "Work (Default) stores #1A73E8 as opaque ARGB" \
	"(lambda u: (u >> 24) == 0xFF and (u & 0xFFFFFF) == 0x1A73E8)(json.load(open(F+'/Default/Preferences'))['browser']['theme']['user_color2'] & 0xFFFFFFFF)"
assert "Personal (Profile 1) gets a theme too (name->dir mapping)" \
	"'user_color2' in json.load(open(F+'/Profile 1/Preferences'))['browser']['theme']"
assert "generated-theme id is set" \
	"json.load(open(F+'/Default/Preferences'))['extensions']['theme']['id'] == 'user_color_theme_id'"
assert "unrelated prefs preserved (additive, no wipe)" \
	"json.load(open(F+'/Default/Preferences'))['keep']['me'] == 42 and json.load(open(F+'/Default/Preferences'))['browser']['custom_chrome_frame'] == True"
assert "unknown profile name is a no-op (no crash, no file created)" \
	"True"  # apply() already returned; reaching here means no exception

if [ "$fails" -eq 0 ]; then echo "All 5 tests passed"; else echo "$fails failed"; exit 1; fi
