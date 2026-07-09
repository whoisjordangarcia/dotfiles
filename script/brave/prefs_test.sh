#!/bin/bash
#===============================================================================
# prefs_test.sh — assertion tests for brave_prefs.py: snapshot captures only
# allowlisted present scalars; apply writes them into every profile additively.
#===============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
FIX=$(mktemp -d)
trap 'rm -rf "$FIX"' EXIT

mkdir -p "$FIX/Default" "$FIX/Profile 1"
cat >"$FIX/Local State" <<'JSON'
{"profile":{"info_cache":{"Default":{"name":"Work"},"Profile 1":{"name":"Personal"}}}}
JSON
# Default has: one allowlisted bool, one allowlisted nested int, one NON-allowlisted
# key (must be ignored), a host-specific exception (must never be captured), and an
# unrelated key to prove additivity.
cat >"$FIX/Default/Preferences" <<'JSON'
{"brave":{"brave_vpn":{"show_button":false},"new_tab_page":{"shows_options":1}},
 "bookmark_bar":{"show_on_all_tabs":true},
 "extensions":{"pinned_extensions":["myown"]},
 "secret":{"password":"nope"},
 "profile":{"content_settings":{"exceptions":{"notifications":{"https://x.com,*":1}}}},
 "keep":42}
JSON
echo '{"keep":7}' >"$FIX/Profile 1/Preferences"

snap="$FIX/prefs.txt"
python3 "$SCRIPT_DIR/brave_prefs.py" snapshot "$FIX/Default/Preferences" >"$snap"
python3 "$SCRIPT_DIR/brave_prefs.py" apply "$FIX" "$snap" >/dev/null
python3 "$SCRIPT_DIR/brave_prefs.py" pin "$FIX" onepass claude >/dev/null

fails=0
assert() {
	if python3 -c "import json,sys; F='$FIX'; sys.exit(0 if ($2) else 1)"; then echo "✓ $1"
	else echo "✗ $1"; fails=$((fails + 1)); fi
}

assert "snapshot captures allowlisted keys only (3), skips non-allowlisted + exceptions" \
	"len([l for l in open(F+'/prefs.txt') if l.strip() and not l.startswith('#')]) == 3 and 'secret' not in open(F+'/prefs.txt').read() and 'exceptions' not in open(F+'/prefs.txt').read()"
assert "apply sets nested key in Work (Default)" \
	"json.load(open(F+'/Default/Preferences'))['brave']['new_tab_page']['shows_options'] == 1"
assert "apply propagates to Personal (Profile 1) too" \
	"json.load(open(F+'/Profile 1/Preferences'))['brave']['brave_vpn']['show_button'] == False and json.load(open(F+'/Profile 1/Preferences'))['bookmark_bar']['show_on_all_tabs'] == True"
assert "unrelated prefs preserved in both (additive)" \
	"json.load(open(F+'/Default/Preferences'))['keep'] == 42 and json.load(open(F+'/Profile 1/Preferences'))['keep'] == 7"
assert "pin unions with existing (keeps 'myown', adds both), order-preserved" \
	"json.load(open(F+'/Default/Preferences'))['extensions']['pinned_extensions'] == ['myown','onepass','claude']"
assert "pin propagates to a profile with no prior pins" \
	"json.load(open(F+'/Profile 1/Preferences'))['extensions']['pinned_extensions'] == ['onepass','claude']"

if [ "$fails" -eq 0 ]; then echo "All 6 tests passed"; else echo "$fails failed"; exit 1; fi
