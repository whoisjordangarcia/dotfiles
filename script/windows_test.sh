#!/bin/bash
# Tests for the `windows` system profile (Git Bash / MSYS2 / Cygwin).
# Runs on any OS: it fakes OSTYPE rather than needing a Windows machine.
set -euo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)
PASSED=0

pass() {
	echo "✓ $1"
	PASSED=$((PASSED + 1))
}

die() {
	echo "✗ $1"
	if [ $# -gt 1 ]; then
		shift
		echo "$@"
	fi
	exit 1
}

# bin/dot runs its main flow when sourced, so lift only the functions under test.
dotfilesDirectory="$REPO_ROOT"
eval "$(sed -n '/^detect_system()/,/^}/p' "$REPO_ROOT/bin/dot")"
eval "$(sed -n '/^get_available_installations()/,/^}/p' "$REPO_ROOT/bin/dot")"
eval "$(sed -n '/^auto_select_installation()/,/^}/p' "$REPO_ROOT/bin/dot")"

# --- detect_system -----------------------------------------------------------

OSTYPE=msys
got=$(detect_system)
[[ "$got" == "windows_" ]] || die "Git Bash (OSTYPE=msys) should detect as windows_" "got: $got"
pass "OSTYPE=msys detects as windows"

OSTYPE=cygwin
got=$(detect_system)
[[ "$got" == "windows_" ]] || die "Cygwin (OSTYPE=cygwin) should detect as windows_" "got: $got"
pass "OSTYPE=cygwin detects as windows"

OSTYPE=darwin23
got=$(detect_system)
[[ "$got" == "mac_" ]] || die "macOS detection regressed" "got: $got"
pass "OSTYPE=darwin23 still detects as mac"

# --- components + installer --------------------------------------------------

[ -f "$REPO_ROOT/script/windows_components.sh" ] || die "script/windows_components.sh is missing"
missing=$(
	source "$REPO_ROOT/script/windows_components.sh"
	[ "${#component_installation[@]}" -gt 0 ] || { echo "component_installation is empty"; exit 0; }
	for c in "${component_installation[@]}"; do
		[ -f "$REPO_ROOT/script/$c/setup.sh" ] || echo "no script/$c/setup.sh"
	done
)
[ -z "$missing" ] || die "windows_components.sh lists components that cannot run" "$missing"
pass "every windows component has a setup.sh"

[ -f "$REPO_ROOT/script/windows_installation.sh" ] || die "script/windows_installation.sh is missing"
bash -n "$REPO_ROOT/script/windows_installation.sh" || die "windows_installation.sh has a syntax error"
grep -qx 'export MSYS=winsymlinks:nativestrict' "$REPO_ROOT/script/windows_installation.sh" ||
	die "windows_installation.sh must export MSYS=winsymlinks:nativestrict (real symlinks or a loud failure)"
pass "installer is valid bash and forces native symlinks"

OSTYPE=msys
got=$(auto_select_installation)
[[ "$got" == "windows" ]] || die "bin/dot should pick the windows installer on Git Bash" "got: '$got'"
pass "auto-selection picks the windows installer on Git Bash"

# `dot run` must list this profile's modules without prompting. A fixture keeps it
# from touching the real .dotconfig.
FIXTURE=$(mktemp -d)
trap 'rm -rf "$FIXTURE"' EXIT
mkdir -p "$FIXTURE/bin" "$FIXTURE/script/common"
cp "$REPO_ROOT/bin/dot" "$FIXTURE/bin/dot"
cp "$REPO_ROOT/script/common/log.sh" "$FIXTURE/script/common/log.sh"
cp "$REPO_ROOT/script/windows_components.sh" "$FIXTURE/script/windows_components.sh"
output=$(cd "$FIXTURE" && ./bin/dot --system windows run 2>&1)
[[ "$output" == *"system=windows"* && "$output" == *git* ]] ||
	die "dot --system windows run did not list the windows modules" "$output"
pass "dot --system windows run lists the windows modules"

echo "All $PASSED tests passed"
