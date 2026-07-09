#!/bin/bash
# Assertion tests for the Brave external-extension manifest helper.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
FIXTURE=$(mktemp -d)
trap 'rm -rf "$FIXTURE"' EXIT

source "$SCRIPT_DIR/../common/log.sh"
source "$SCRIPT_DIR/soft_install.sh"

VALID_ID="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
printf '%s  # valid extension\n../../outside\n' "$VALID_ID" >"$FIXTURE/extensions.txt"
brave_soft_install "$FIXTURE/extensions.txt" "$FIXTURE/manifests" >/dev/null

if [[ -f "$FIXTURE/manifests/$VALID_ID.json" && ! -e "$FIXTURE/outside.json" ]]; then
	echo "✓ writes manifests only for valid extension IDs"
else
	echo "✗ malformed extension ID was not safely rejected"
	exit 1
fi
