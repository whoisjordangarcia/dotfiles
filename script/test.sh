#!/bin/bash
# test.sh — run every *_test.sh in the repo (or those whose path matches $1).
#
#   script/test.sh            all suites
#   script/test.sh brave      only paths containing "brave"
#
# Each suite runs as its own process from the repo root; its output is shown
# only when it fails. A suite that exits 77 is reported as skipped (wrong
# OS/hardware). Exits non-zero if any suite failed.
set -uo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)
cd "$ROOT"
source script/common/log.sh

filter="${1:-}"
passed=0
skipped=0
failed=()

while IFS= read -r t; do
	[[ -z "$filter" || "$t" == *"$filter"* ]] || continue
	start=$SECONDS
	out=$(bash "$t" </dev/null 2>&1)
	rc=$?
	if [[ $rc -eq 0 ]]; then
		printf '  \033[0;32m✓\033[0m %s (%ss)\n' "$t" $((SECONDS - start))
		passed=$((passed + 1))
	elif [[ $rc -eq 77 ]]; then
		printf '  \033[0;33m-\033[0m %s (skipped: %s)\n' "$t" "$(tail -1 <<<"$out")"
		skipped=$((skipped + 1))
	else
		printf '  \033[0;31m✗\033[0m %s (%ss)\n' "$t" $((SECONDS - start))
		printf '%s\n' "$out" | sed 's/^/      /'
		failed+=("$t")
	fi
done < <(git ls-files '*_test.sh')

echo ""
if [[ ${#failed[@]} -eq 0 ]]; then
	success "$passed suites passed, $skipped skipped"
else
	fail "${#failed[@]} failed, $passed passed, $skipped skipped: ${failed[*]}"
fi
