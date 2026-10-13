#!/bin/bash
#===============================================================================
# settings_test.sh — assertions for settings_schema.py, offline.
#
# The fixture reference below mirrors the real settings-reference.md format (the
# summary table plus one `### \`key\`` section per key), pinning the parsing and
# every check against a known input.
#
#   bash configs/claude/settings_test.sh   # must end with "All N tests passed"
#===============================================================================

set -uo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
CHECK="$SCRIPT_DIR/settings_schema.py"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat >"$TMP/ref.md" <<'EOF'
| Key | What it does | Category | Scope |
| --- | --- | --- | --- |
| [`attribution`](#attribution) | Customize the attribution | Git and attribution | Any file |
| [`attribution.commit`](#attribution-commit) | Change or hide the trailer | Git and attribution | Any file |
| [`autoConnectIde`](#autoconnectide) | Connect to a running IDE | Global config settings | Global config |
| [`effortLevel`](#effortlevel) | Set the effort level | Model | Any file |
| [`feedbackDrafts`](#feedbackdrafts) | Control feedback drafts | Privacy and telemetry | User or managed |
| [`includeCoAuthoredBy`](#includecoauthoredby) | Deprecated; use `attribution` to hide or change [commit](#x) attribution | Git and attribution | Any file |
| [`requiredMinimumVersion`](#requiredminimumversion) | Refuse to start on an older version | Updates and versioning | Managed |
| [`voiceEnabled`](#voiceenabled) | Turn on voice dictation with the older single-key form | Interface and terminal | Any file |
| [`taskOutputMaxChars`](#taskoutputmaxchars) | Removed in v2.1.277, together with the `TaskOutput` tool | Memory and context | Any file |

### `attribution`

* **Scope**: [`Any file`](#scopes)
* **Type**: object with `commit` and `pr` strings and a `sessionUrl` Boolean, or `false` to hide all attribution

### `attribution.commit`

* **Type**: string

### `autoConnectIde`

* **Type**: Boolean

### `effortLevel`

* **Type**: string, one of:
  * `"low"`: the least reasoning
  * `"high"`: balances token usage and intelligence
* **Default**: unset

### `feedbackDrafts`

* **Type**: string, one of `"notify"`, `"quiet"`, or `"off"`. A `"loud"` value is not a value
  * `"notify"`: shows a card

### `includeCoAuthoredBy`

* **Type**: Boolean

### `requiredMinimumVersion`

* **Type**: string, a version number such as `2.1.0`

### `voiceEnabled`

<Warning>
  Deprecated since v2.1.92, when the [`voice`](#voice) object replaced it. Claude Code still reads it.
</Warning>

* **Type**: Boolean

### `taskOutputMaxChars`

* **Type**: number
EOF

cat >"$TMP/base.json" <<'EOF'
{"$id": "https://json.schemastore.org/claude-code-settings.json", "type": "object",
 "properties": {"attribution": {"type": "object", "description": "from schemastore"}}}
EOF

pass=0
fail=0

# assert <expect-pass|expect-fail> <label> <settings-json> [expected-output-substring]
assert() {
	local mode="$1" label="$2" body="$3" want="${4:-}" out rc
	printf '%s' "$body" >"$TMP/s.json"
	out=$("$CHECK" --ref "$TMP/ref.md" --base "$TMP/base.json" --out "$TMP/schema.json" "$TMP/s.json" 2>&1)
	rc=$?
	if { [[ "$mode" == "expect-pass" && $rc -eq 0 ]] || [[ "$mode" == "expect-fail" && $rc -eq 1 ]]; } &&
		[[ -z "$want" || "$out" == *"$want"* ]]; then
		echo "  ✓ $label"
		pass=$((pass + 1))
	else
		echo "  ✗ $label (exit=$rc, expected $mode${want:+, output containing '$want'})"
		echo "$out" | sed 's/^/      /'
		fail=$((fail + 1))
	fi
}

# check_schema <label> <python expression over `p` (the generated properties)>
check_schema() {
	if python3 -I -c "import json,sys; p=json.load(open(sys.argv[1]))['properties']; sys.exit(0 if ($2) else 1)" "$TMP/schema.json"; then
		echo "  ✓ $1"
		pass=$((pass + 1))
	else
		echo "  ✗ $1"
		fail=$((fail + 1))
	fi
}

echo "check:"
assert expect-pass "valid settings pass" \
	'{"$schema":"./settings.schema.json","effortLevel":"high","feedbackDrafts":"off","attribution":{"commit":""}}'
assert expect-pass "a key Claude Code writes itself passes" '{"skipWorkflowUsageWarning":true}'
assert expect-pass "a union type admits each of its members" '{"attribution":false}'
assert expect-fail "deprecated key is flagged, with the docs' reason" '{"includeCoAuthoredBy":false}' 'Deprecated; use `attribution`'
assert expect-fail "the reason drops markdown link targets" '{"includeCoAuthoredBy":false}' 'change commit attribution'
assert expect-fail "a key retired only in its section's <Warning> is flagged" '{"voiceEnabled":true}' 'Deprecated since v2.1.92, when the `voice` object'
assert expect-fail "removed key is flagged" '{"taskOutputMaxChars":1}' 'Removed in v2.1.277'
assert expect-fail "undocumented key is flagged" '{"mcpServers":{}}' 'mcpServers: not in the settings reference'
assert expect-fail "Global config key is flagged" '{"autoConnectIde":true}' '~/.claude.json'
assert expect-fail "Managed-only key is flagged" '{"requiredMinimumVersion":"2.1.0"}' 'managed settings only'
assert expect-fail "wrong type is flagged" '{"feedbackDrafts":false}' 'is boolean false, docs allow string'
assert expect-fail "inline enum rejects an unlisted value" '{"feedbackDrafts":"loud"}' 'not one of notify, quiet, off'
assert expect-fail "bullet enum rejects an unlisted value" '{"effortLevel":"max"}' 'not one of low, high'
assert expect-fail "nested documented key is type-checked" '{"attribution":{"commit":false}}' 'attribution.commit: is boolean'

echo "schema:"
check_schema "schemastore entries are kept" 'p["attribution"]["description"] == "from schemastore"'
check_schema "keys schemastore lacks are added with their type" 'p["feedbackDrafts"]["type"] == "string" and p["feedbackDrafts"]["enum"] == ["notify","quiet","off"]'
check_schema "deprecated keys carry deprecated + deprecationMessage" 'p["includeCoAuthoredBy"]["deprecated"] is True and p["includeCoAuthoredBy"]["deprecationMessage"].startswith("Deprecated")'
check_schema "keys settings.json ignores are struck through too" 'p["autoConnectIde"].get("deprecated") is True'
check_schema "live keys are not marked deprecated" '"deprecated" not in p["effortLevel"]'
check_schema "dotted keys stay out of top-level properties" '"attribution.commit" not in p'

echo "docs format:"
printf 'no table here\n' >"$TMP/empty.md"
"$CHECK" --ref "$TMP/empty.md" --base "$TMP/base.json" --out "$TMP/schema.json" "$TMP/s.json" >/dev/null 2>&1
if [[ $? -eq 2 ]]; then
	echo "  ✓ an unparseable reference exits 2 instead of passing everything"
	pass=$((pass + 1))
else
	echo "  ✗ an unparseable reference exits 2 instead of passing everything"
	fail=$((fail + 1))
fi

echo
if [[ $fail -eq 0 ]]; then
	echo "All $pass tests passed"
	exit 0
fi
echo "$fail of $((pass + fail)) tests FAILED"
exit 1
