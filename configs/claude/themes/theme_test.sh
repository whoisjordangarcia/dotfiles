#!/bin/bash
#===============================================================================
# theme_test.sh — assertions for theme_preview.py --check.
#
# theme_preview.py re-implements an UNDOCUMENTED contract reverse-engineered from
# the Claude Code binary (ghg()/JOe()/Wdi/Kpg/mhg). The loader drops bad keys and
# bad colors SILENTLY, so --check is the only thing standing between a typo and a
# subtly-wrong theme. If --check ever passes something the loader would discard,
# it is worse than useless — it certifies the bug. These fixtures pin that.
#
# The contract WILL drift on Claude Code upgrades. When it does, this should be
# the thing that fails. Re-extract with:
#   strings -n 4 ~/.local/share/claude/versions/<v> | grep -o 'function JOe(e).\{0,700\}'
#   strings -n 3 ~/.local/share/claude/versions/<v> | grep -o 'Kpg=[^;]\{0,300\}'
#
#   bash configs/claude/themes/theme_test.sh   # must end with "All N tests passed"
#===============================================================================

set -uo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PREVIEW="$SCRIPT_DIR/theme_preview.py"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0

# assert <expect-pass|expect-fail> <label> <json-body>
assert() {
	local mode="$1" label="$2" body="$3" out rc
	printf '%s' "$body" >"$TMP/t.json"
	out=$("$PREVIEW" --check "$TMP/t.json" 2>&1)
	rc=$?
	if { [[ "$mode" == "expect-pass" && $rc -eq 0 ]]; } ||
		{ [[ "$mode" == "expect-fail" && $rc -ne 0 ]]; }; then
		echo "  ✓ $label"
		pass=$((pass + 1))
	else
		echo "  ✗ $label (exit=$rc, expected $mode)"
		echo "$out" | sed 's/^/      /'
		fail=$((fail + 1))
	fi
}

echo "the shipped theme"
if "$PREVIEW" --check >/dev/null 2>&1; then
	echo "  ✓ every theme in configs/claude/themes passes --check"
	pass=$((pass + 1))
else
	echo "  ✗ a shipped theme FAILS --check"
	"$PREVIEW" --check 2>&1 | sed 's/^/      /'
	fail=$((fail + 1))
fi

echo
echo "silent-drop guards (the whole point of --check)"
assert expect-fail "unknown key (typo) is caught" \
	'{"name":"T","base":"dark","overrides":{"autoAccpet":"#cba6f7"}}'
assert expect-fail "hex without # is caught" \
	'{"name":"T","base":"dark","overrides":{"text":"cdd6f4"}}'
assert expect-fail "CSS color name is caught" \
	'{"name":"T","base":"dark","overrides":{"error":"rebeccapurple"}}'
assert expect-fail "invalid base is caught" \
	'{"name":"T","base":"mocha","overrides":{"text":"#cdd6f4"}}'
assert expect-fail "malformed JSON is caught" \
	'{"name":"T","base":"dark",}'
assert expect-fail "non-object overrides is caught" \
	'{"name":"T","base":"dark","overrides":[1,2]}'
assert expect-fail "non-string color is caught" \
	'{"name":"T","base":"dark","overrides":{"text":123}}'

echo
echo "ansi: is a MEMBERSHIP test (Kpg.has), not a prefix check"
# Regression: a bare ^ansi: prefix regex green-lit these, but the loader drops
# them — --check would have certified a theme that renders wrong.
assert expect-fail "ansi:orange is not one of the 16 names" \
	'{"name":"T","base":"dark","overrides":{"claude":"ansi:orange"}}'
assert expect-fail "ansi:notacolor is caught" \
	'{"name":"T","base":"dark","overrides":{"text":"ansi:notacolor"}}'
assert expect-fail "bare ansi: is caught" \
	'{"name":"T","base":"dark","overrides":{"text":"ansi:"}}'
assert expect-pass "ansi:magenta is valid" \
	'{"name":"T","base":"dark","overrides":{"bashBorder":"ansi:magenta"}}'
assert expect-pass "ansi:magentaBright is valid" \
	'{"name":"T","base":"dark","overrides":{"bashBorder":"ansi:magentaBright"}}'

echo
echo "accepted color formats (JOe)"
assert expect-pass "#rrggbb" '{"name":"T","base":"dark","overrides":{"text":"#cdd6f4"}}'
assert expect-pass "#rgb"    '{"name":"T","base":"dark","overrides":{"text":"#abc"}}'
assert expect-pass "rgb(r,g,b)" '{"name":"T","base":"dark","overrides":{"text":"rgb(205,214,244)"}}'
assert expect-pass "rgb with spaces" '{"name":"T","base":"dark","overrides":{"text":"rgb(205, 214, 244)"}}'
assert expect-pass "ansi256(n)" '{"name":"T","base":"dark","overrides":{"text":"ansi256(140)"}}'
assert expect-fail "#rrggbbaa (4-byte hex) is rejected" \
	'{"name":"T","base":"dark","overrides":{"text":"#cdd6f4ff"}}'
# Python's `$` matches before a trailing newline; JS's does not. re.fullmatch fixes it.
assert expect-fail "trailing newline in a color is rejected" \
	'{"name":"T","base":"dark","overrides":{"text":"#cdd6f4\n"}}'

echo
echo "valid themes must PASS (advisory notes are not errors)"
assert expect-pass "a valid light theme" \
	'{"name":"L","base":"light","overrides":{"text":"#4c4f69"}}'
assert expect-pass "every valid base" \
	'{"name":"D","base":"dark-daltonized","overrides":{"text":"#cdd6f4"}}'
assert expect-pass "partial theme (overrides merge over base)" \
	'{"name":"P","base":"dark","overrides":{"claude":"#fab387"}}'
assert expect-pass "no overrides is valid (identical to base)" \
	'{"name":"E","base":"dark"}'
assert expect-pass "no base defaults to dark" \
	'{"name":"N","overrides":{"text":"#cdd6f4"}}'

echo
if [[ $fail -eq 0 ]]; then
	echo "All $pass tests passed"
	exit 0
fi
echo "$fail of $((pass + fail)) tests FAILED"
exit 1
