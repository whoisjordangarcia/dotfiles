#!/bin/bash
# Tests for the git module: it must not destroy an existing ~/.gitconfig, and the
# generated one must only name tools the machine has. Runs against a scratch HOME
# with a PATH holding just the tools the module needs, so bat/nvim can be absent.
set -euo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
PASSED=0

pass() {
	echo "✓ $1"
	PASSED=$((PASSED + 1))
}
die() {
	echo "✗ $1"
	shift
	[ $# -eq 0 ] || echo "$@"
	exit 1
}

# A PATH with only what setup.sh, log.sh and symlink.sh call.
BIN="$TMP/bin"
mkdir -p "$BIN"
for tool in bash git sed grep cat cp mv rm ln mkdir date dirname basename readlink realpath uname python3; do
	path=$(command -v "$tool" 2>/dev/null) || continue
	ln -s "$path" "$BIN/$tool"
done
stub() { printf '#!/bin/sh\nexit 0\n' >"$BIN/$1" && chmod +x "$BIN/$1"; }

# run_setup <home> — fixed identity, no signing key, never prompts
run_setup() {
	mkdir -p "$1"
	env -i PATH="$BIN" HOME="$1" DOT_NAME="Test & User" DOT_EMAIL="test@example.com" DOT_SIGNING_KEY="" \
		DOT_SYMLINK_MODE=backup GIT_CONFIG_NOSYSTEM=1 bash "$REPO_ROOT/script/git/setup.sh" >"$TMP/out" 2>&1 ||
		die "git/setup.sh failed" "$(cat "$TMP/out")"
}

# --- no bat, no nvim (Windows, a bare server) ---------------------------------
H="$TMP/bare"
mkdir -p "$H"
printf '[user]\n\tname = Someone Else\n[alias]\n\tmine = status\n' >"$H/.gitconfig"
rm -f "$BIN/vim" "$BIN/vi"
stub vim
run_setup "$H"

backup=$(find "$H" -maxdepth 1 -name '.gitconfig_*.bak' | head -1)
[ -n "$backup" ] && grep -q 'mine = status' "$backup" || die "a hand-written ~/.gitconfig was not backed up"
pass "an existing ~/.gitconfig is moved aside, not deleted"

grep -q 'pager = ' "$H/.gitconfig" && die "pager still set with no bat on PATH" "$(grep pager "$H/.gitconfig")"
pass "no bat: the pager line is dropped"

grep -q 'editor = vim$' "$H/.gitconfig" || die "editor did not fall back to vim" "$(grep editor "$H/.gitconfig")"
pass "no nvim: the editor falls back to vim"

[ "$(env -i PATH="$BIN" HOME="$H" git config --global user.name)" = "Test & User" ] ||
	die "a name containing & was mangled" "$(grep 'name =' "$H/.gitconfig")"
pass "sed metacharacters in the name survive"

grep -q 'signingkey\|gpgsign' "$H/.gitconfig" && die "signing config left in place without a key"
pass "no signing key: signing config is removed"

run_setup "$H"
[ "$(find "$H" -maxdepth 1 -name '.gitconfig_*.bak' | wc -l | tr -d ' ')" = 1 ] ||
	die "a rerun backed up the config this script generated"
pass "a rerun regenerates in place without another backup"

# --- batcat (Debian/Ubuntu package name) ---------------------------------------
stub batcat
run_setup "$TMP/debian"
grep -q 'pager = batcat$' "$TMP/debian/.gitconfig" || die "pager not rewritten to batcat"
pass "batcat: the pager is rewritten to batcat"
rm -f "$BIN/batcat"

# --- bat and nvim present (mac, Arch, Omarchy) ---------------------------------
stub bat
stub nvim
run_setup "$TMP/full"
grep -q 'pager = bat$' "$TMP/full/.gitconfig" && grep -q 'editor = nvim$' "$TMP/full/.gitconfig" ||
	die "bat/nvim were replaced although both are installed"
pass "bat and nvim present: the template values are kept"

echo "All $PASSED tests passed"
