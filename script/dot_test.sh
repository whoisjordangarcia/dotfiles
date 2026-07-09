#!/bin/bash
# Regression tests for bin/dot's configuration precedence.
set -euo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)
FIXTURE=$(mktemp -d)
trap 'rm -rf "$FIXTURE"' EXIT

mkdir -p "$FIXTURE/bin" "$FIXTURE/script/common"
cp "$REPO_ROOT/bin/dot" "$FIXTURE/bin/dot"
cp "$REPO_ROOT/script/common/log.sh" "$FIXTURE/script/common/log.sh"
printf 'DOT_NAME="Test User"\nDOT_EMAIL="test@example.com"\nDOT_YUBIKEY=""\nDOT_SYSTEM="linux_arch"\nDOT_ENVIRONMENT="work"\n' >"$FIXTURE/.dotconfig"

# No installation script exists in the fixture. That makes the direct install
# fail safely after resolving its configuration, so no installer can run.
if output=$(cd "$FIXTURE" && ./bin/dot --system linux_ubuntu --personal 2>&1); then
	echo "✗ direct install unexpectedly succeeded"
	exit 1
fi

if grep -qx 'DOT_SYSTEM="linux_ubuntu"' "$FIXTURE/.dotconfig" &&
	grep -qx 'DOT_ENVIRONMENT="personal"' "$FIXTURE/.dotconfig"; then
	echo "✓ explicit --system and --personal override .dotconfig"
else
	echo "✗ CLI overrides were replaced by .dotconfig"
	echo "$output"
	exit 1
fi
