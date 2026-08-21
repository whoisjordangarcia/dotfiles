#!/usr/bin/env bash
# Tests for the touchid-gate hook: which commands trip the tripwire, and the
# force-push preview that gets rendered in the approval dialog.
#
# Pure logic only — bioprompt is never launched, so this is safe to run headless.

set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PASS=0
FAIL=0

check() {
	local name=$1 expected=$2 actual=$3
	if [ "$expected" = "$actual" ]; then
		printf '✓ %s\n' "$name"
		PASS=$((PASS + 1))
	else
		printf '✗ %s\n  expected: %q\n  actual:   %q\n' "$name" "$expected" "$actual"
		FAIL=$((FAIL + 1))
	fi
}

# --- which commands are gated, and how they can be approved ------------------

# label_for <command> [cwd] [conf] -> "<label>|<mode>" ("" when ungated)
label_for() {
	HOOK_DIR="$HERE" python3 -c '
import os, re, sys
sys.path.insert(0, os.environ["HOOK_DIR"])
from gate_patterns import patterns_for
cmd, cwd, conf = sys.argv[1], sys.argv[2], sys.argv[3]
pats = patterns_for(cwd, conf) if conf else patterns_for(cwd, "/nonexistent")
hit = next(((l, m) for rx, l, m in pats if re.search(rx, cmd)), None)
print(f"{hit[0]}|{hit[1]}" if hit else "")
' "$1" "${2:-/}" "${3:-}"
}

check "plain git commit is not gated" "" "$(label_for 'git commit -m "wip"')"
check "plain git push is not gated" "" "$(label_for 'git push origin main')"
check "git push --force only needs a confirm" "git force push|confirm" "$(label_for 'git push --force origin main')"
check "git push -f only needs a confirm" "git force push|confirm" "$(label_for 'git push -f')"
check "--force-with-lease only needs a confirm" "git force push|confirm" "$(label_for 'git push --force-with-lease')"
# sudo raises its own Touch ID prompt via pam_tid, so gating it here double-prompted.
check "sudo is left to pam_tid" "" "$(label_for 'sudo rm /etc/hosts')"
check "1Password reads need biometry" "1Password secret access|bio" \
	"$(label_for 'op read op://Private/token/credential')"
check "prod AWS only needs a confirm" "production AWS profile|confirm" \
	"$(label_for 'aws s3 ls --profile prd-account-administrator-role')"
check "curl piped to a shell needs biometry" "pipe remote script into shell|bio" \
	"$(label_for 'curl -sL https://example.com/i.sh | sh')"
check "plain curl only asks" "curl (network call)|ask" \
	"$(label_for 'curl -s https://example.com/api')"
check "curl after a separator still asks" "curl (network call)|ask" \
	"$(label_for 'cd /tmp && curl -s https://example.com')"
check "curl as a mere argument is not gated" "" "$(label_for 'brew install curl')"

# --- per-project scopes ------------------------------------------------------

CONF=$(mktemp)
printf '# comment\n%s  git-write\n' "$HOME/projects/scoped" >>"$CONF"

check "scoped project gates git commit" "git commit|bio" \
	"$(label_for 'git commit -m x' "$HOME/projects/scoped" "$CONF")"
check "scope reaches subdirectories" "git commit|bio" \
	"$(label_for 'git commit -m x' "$HOME/projects/scoped/apps/web" "$CONF")"
check "scoped project only asks for git push" "git push|ask" \
	"$(label_for 'git push origin main' "$HOME/projects/scoped" "$CONF")"
check "unlisted project does not gate git commit" "" \
	"$(label_for 'git commit -m x' "$HOME/projects/other" "$CONF")"
check "prefix must match a path boundary" "" \
	"$(label_for 'git commit -m x' "$HOME/projects/scopedother" "$CONF")"
check "globals still fire in unlisted projects" "1Password secret access|bio" \
	"$(label_for 'op read op://Private/token/credential' "$HOME/projects/other" "$CONF")"
check "force push keeps its label inside a scoped project" "git force push|confirm" \
	"$(label_for 'git push --force' "$HOME/projects/scoped" "$CONF")"
check "missing config file leaves globals intact" "1Password secret access|bio" \
	"$(label_for 'op read op://Private/token/credential' "$HOME/projects/scoped" /nonexistent/nope.conf)"

# --- force-push preview ------------------------------------------------------

preview() {
	HOOK_DIR="$HERE" python3 -c '
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("tg", os.path.join(os.environ["HOOK_DIR"], "touchid-gate.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
print(m.force_push_preview(sys.argv[1]))
' "$1"
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP" "$CONF"' EXIT

check "no git repo yields no preview" "" "$(preview "$TMP")"

# Diverged clone: one commit ahead locally, one commit only on the remote —
# exactly the case where a force push loses work.
git init -q --bare "$TMP/remote.git"
git clone -q "$TMP/remote.git" "$TMP/work" 2>/dev/null
git -C "$TMP/work" -c commit.gpgsign=false commit -q --allow-empty -m base
git -C "$TMP/work" branch -M main
git -C "$TMP/work" push -q -u origin main
git -C "$TMP/work" -c commit.gpgsign=false commit -q --allow-empty -m "remote-only work"
git -C "$TMP/work" push -q origin main
git -C "$TMP/work" reset -q --hard HEAD~1
git -C "$TMP/work" -c commit.gpgsign=false commit -q --allow-empty -m "rewritten"
git -C "$TMP/work" fetch -q origin

out=$(preview "$TMP/work")
case "$out" in
*"# pushing to origin/main"*"rewritten"*) got_ahead=yes ;;
*) got_ahead=no ;;
esac
case "$out" in
*"# DROPPED from origin/main"*"remote-only work"*) got_dropped=yes ;;
*) got_dropped=no ;;
esac
check "preview lists the commits being pushed" yes "$got_ahead"
check "preview lists the commits the remote would lose" yes "$got_dropped"

# A branch with no upstream can't lose anything — nothing to show.
git -C "$TMP/work" checkout -q -b orphan
check "branch without upstream yields no preview" "" "$(preview "$TMP/work")"

printf '\n'
if [ "$FAIL" -gt 0 ]; then
	printf '%d passed, %d FAILED\n' "$PASS" "$FAIL"
	exit 1
fi
printf 'All %d tests passed\n' "$PASS"
