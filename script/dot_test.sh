#!/bin/bash
# Regression tests for bin/dot's configuration precedence.
set -euo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)
FIXTURE=$(mktemp -d)
trap 'rm -rf "$FIXTURE"' EXIT

mkdir -p "$FIXTURE/bin" "$FIXTURE/script/common"
cp "$REPO_ROOT/bin/dot" "$FIXTURE/bin/dot"
cp "$REPO_ROOT/script/common/log.sh" "$FIXTURE/script/common/log.sh"
printf 'DOT_NAME="Test User"\nDOT_EMAIL="test@example.com"\nDOT_SIGNING_KEY=""\nDOT_SYSTEM="linux_arch"\nDOT_ENVIRONMENT="work"\n' >"$FIXTURE/.dotconfig"

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

# Fresh machine: no .dotconfig at all. Every DOT_* read must survive `set -u`,
# so the failure must be the missing installer — not "unbound variable".
rm -f "$FIXTURE/.dotconfig"
output=$(cd "$FIXTURE" && ./bin/dot --system linux_ubuntu --personal 2>&1) || true
if [[ "$output" == *"unbound variable"* ]]; then
	echo "✗ direct install on an unconfigured machine tripped set -u"
	echo "$output"
	exit 1
fi
if grep -qx 'DOT_SYSTEM="linux_ubuntu"' "$FIXTURE/.dotconfig"; then
	echo "✓ direct install works with no .dotconfig present"
else
	echo "✗ no .dotconfig was written on a fresh direct install"
	echo "$output"
	exit 1
fi

# `dot -m` reads DOT_SYSTEM straight out of the (absent) config too.
rm -f "$FIXTURE/.dotconfig"
output=$(cd "$FIXTURE" && ./bin/dot -m </dev/null 2>&1) || true
if [[ "$output" == *"unbound variable"* ]]; then
	echo "✗ dot -m on an unconfigured machine tripped set -u"
	echo "$output"
	exit 1
fi
echo "✓ dot -m works with no .dotconfig present"

# `dot run` is the non-interactive path agents use: it must list the system's
# modules (honouring --work guards) and fail on an unknown module.
printf 'DOT_SYSTEM="linux_arch"\nDOT_ENVIRONMENT="personal"\n' >"$FIXTURE/.dotconfig"
printf 'component_installation=(git)\n[[ "${WORK_ENV:-}" == "1" ]] && component_installation+=(work-only)\n' \
	>"$FIXTURE/script/linux_arch_components.sh"
output=$(cd "$FIXTURE" && ./bin/dot run 2>&1)
if [[ "$output" == *"system=linux_arch environment=personal"* && "$output" == *git* && "$output" != *work-only* ]]; then
	echo "✓ dot run lists the configured system's modules"
else
	echo "✗ dot run listing is wrong"
	echo "$output"
	exit 1
fi
output=$(cd "$FIXTURE" && ./bin/dot --work run 2>&1)
if [[ "$output" == *work-only* ]]; then
	echo "✓ dot --work run includes work-only modules"
else
	echo "✗ dot --work run missed work-only modules"
	echo "$output"
	exit 1
fi
if (cd "$FIXTURE" && ./bin/dot run no-such-module >/dev/null 2>&1); then
	echo "✗ dot run accepted an unknown module"
	exit 1
fi
echo "✓ dot run fails on an unknown module"
