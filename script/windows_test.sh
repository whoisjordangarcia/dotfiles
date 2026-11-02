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

echo "All $PASSED tests passed"
