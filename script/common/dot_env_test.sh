#!/bin/bash
#===============================================================================
# dot_env_test.sh — assertions for dot_resolve_env().
#
# This resolver decides whether a machine installs the WORK or PERSONAL config.
# Getting it wrong is a silent security regression (a work box installing the
# personal settings drops the touchid-gate + prod-AWS tripwires and every nest-*
# plugin), so every precedence rule is pinned here.
#
#   bash script/common/dot_env_test.sh   # must end with "All N tests passed"
#===============================================================================

set -uo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

pass=0
fail=0

# check <expected> <label> [WORK_ENV] [DOT_ENVIRONMENT] [dotconfig-body]
# An empty WORK_ENV/DOT_ENVIRONMENT arg means "not set at all". Use the literal
# EMPTY to mean "exported but empty" (what bin/dot does for personal).
check() {
	local expected="$1" label="$2" we="${3:-}" de="${4:-}" body="${5:-__NONE__}"
	local tmp got
	tmp=$(mktemp -d)
	[[ "$body" != "__NONE__" ]] && printf '%s\n' "$body" >"$tmp/.dotconfig"

	got=$(
		# Subshell: env + sourced lib stay contained per case.
		unset WORK_ENV DOT_ENVIRONMENT
		[[ -n "$we" ]] && { [[ "$we" == "EMPTY" ]] && export WORK_ENV="" || export WORK_ENV="$we"; }
		[[ -n "$de" ]] && { [[ "$de" == "EMPTY" ]] && export DOT_ENVIRONMENT="" || export DOT_ENVIRONMENT="$de"; }
		# shellcheck disable=SC1091
		source "$SCRIPT_DIR/dot_env.sh" >/dev/null 2>&1
		dot_resolve_env "$tmp/.dotconfig"
	)
	rm -rf "$tmp"

	if [[ "$got" == "$expected" ]]; then
		echo "  ✓ $label → $got"
		pass=$((pass + 1))
	else
		echo "  ✗ $label → $got (expected $expected)"
		fail=$((fail + 1))
	fi
}

echo "dot_resolve_env — .dotconfig fallback (the standalone install path)"
# THE BUG: work machine, standalone run, nothing exported. Must NOT be personal.
check work     'work .dotconfig, nothing exported (THE BUG)'   ""  "" 'DOT_ENVIRONMENT="work"'
check personal 'personal .dotconfig, nothing exported'         ""  "" 'DOT_ENVIRONMENT="personal"'
check personal 'no .dotconfig at all (LXC/fresh box)'          ""  ""
check personal '.dotconfig without DOT_ENVIRONMENT'            ""  "" 'DOT_NAME="Jordan Garcia"'

echo
echo "dot_resolve_env — .dotconfig parsing"
# grep+cut '"' returned the whole line for unquoted values and fell back to
# personal — i.e. silently back into the bug. `source` handles both forms.
check work 'unquoted DOT_ENVIRONMENT=work'                     ""  "" 'DOT_ENVIRONMENT=work'
check work 'single-quoted DOT_ENVIRONMENT'                     ""  "" "DOT_ENVIRONMENT='work'"
check work 'DOT_ENVIRONMENT=work among other keys'             ""  "" 'DOT_NAME="J"
DOT_ENVIRONMENT="work"
DOT_SYSTEM="mac"'
check personal 'commented-out DOT_ENVIRONMENT=work'            ""  "" '#DOT_ENVIRONMENT="work"'

echo
echo "dot_resolve_env — explicit env wins over .dotconfig"
check work     'WORK_ENV=1 overrides personal .dotconfig'      "1" "" 'DOT_ENVIRONMENT="personal"'
check work     'DOT_ENVIRONMENT=work overrides personal file'  ""  "work" 'DOT_ENVIRONMENT="personal"'
check personal 'DOT_ENVIRONMENT=personal overrides work file'  ""  "personal" 'DOT_ENVIRONMENT="work"'
check work     'WORK_ENV=1, no .dotconfig'                     "1" ""

echo
echo "dot_resolve_env — bin/dot's exact calling convention"
# bin/dot exports WORK_ENV="" (empty, NOT unset) + DOT_ENVIRONMENT for personal.
# An empty WORK_ENV must carry no signal, or personal machines resolve wrong.
check personal 'bin/dot personal: WORK_ENV="" + DOT_ENVIRONMENT=personal' "EMPTY" "personal" 'DOT_ENVIRONMENT="personal"'
check work     'bin/dot work: WORK_ENV=1 + DOT_ENVIRONMENT=work'          "1" "work" 'DOT_ENVIRONMENT="work"'
# Empty WORK_ENV must not mask a work .dotconfig on a standalone run.
check work     'WORK_ENV="" alone, work .dotconfig'                       "EMPTY" "" 'DOT_ENVIRONMENT="work"'
check personal 'WORK_ENV=0 is not 1'                                      "0" "" 'DOT_ENVIRONMENT="personal"'

echo
echo "dot_env.sh — sourcing is side-effect free"
# Sourcing must not resolve/export: doing so feeds back into the precedence
# rules and makes a later dot_resolve_env return the source-time answer for any
# .dotconfig handed to it.
side_effects=$(
	unset WORK_ENV DOT_ENVIRONMENT DOT_ENV
	# shellcheck disable=SC1091
	source "$SCRIPT_DIR/dot_env.sh" >/dev/null 2>&1
	echo "${DOT_ENV:-unset}:${WORK_ENV:-unset}:${DOT_ENVIRONMENT:-unset}"
)
if [[ "$side_effects" == "unset:unset:unset" ]]; then
	echo "  ✓ source sets nothing until dot_export_env is called"
	pass=$((pass + 1))
else
	echo "  ✗ source had side effects ($side_effects)"
	fail=$((fail + 1))
fi

echo
echo "dot_export_env — sets DOT_ENV + exports coherently"
for want in work personal; do
	got=$(
		unset WORK_ENV DOT_ENVIRONMENT DOT_ENV
		tmp=$(mktemp -d)
		printf 'DOT_ENVIRONMENT="%s"\n' "$want" >"$tmp/.dotconfig"
		# shellcheck disable=SC1091
		source "$SCRIPT_DIR/dot_env.sh" >/dev/null 2>&1
		dot_export_env "$tmp/.dotconfig"
		# NOTE ${VAR-x} not ${VAR:-x}: the personal path exports WORK_ENV=""
		# (set-but-empty, mirroring bin/dot), and only the colon-less form
		# distinguishes that from genuinely unset.
		echo "${DOT_ENV}:${WORK_ENV-unset}:${DOT_ENVIRONMENT-unset}"
		rm -rf "$tmp"
	)
	if [[ "$want" == "work" ]]; then expect="work:1:work"; else expect="personal::personal"; fi
	if [[ "$got" == "$expect" ]]; then
		echo "  ✓ $want: DOT_ENV/WORK_ENV/DOT_ENVIRONMENT agree ($got)"
		pass=$((pass + 1))
	else
		echo "  ✗ $want: got ($got), expected ($expect)"
		fail=$((fail + 1))
	fi
done

# The exports must survive into a CHILD process — components run as children and
# only see the exported environment.
child=$(
	unset WORK_ENV DOT_ENVIRONMENT DOT_ENV
	tmp=$(mktemp -d)
	printf 'DOT_ENVIRONMENT="work"\n' >"$tmp/.dotconfig"
	# shellcheck disable=SC1091
	source "$SCRIPT_DIR/dot_env.sh" >/dev/null 2>&1
	dot_export_env "$tmp/.dotconfig"
	bash -c 'echo "${WORK_ENV:-unset}:${DOT_ENVIRONMENT:-unset}"'
	rm -rf "$tmp"
)
if [[ "$child" == "1:work" ]]; then
	echo "  ✓ exports reach child processes ($child)"
	pass=$((pass + 1))
else
	echo "  ✗ exports did not reach child ($child)"
	fail=$((fail + 1))
fi

# .dotconfig must not leak its other vars into the caller (it is sourced in a
# subshell precisely to avoid clobbering DOT_NAME/SCRIPT_DIR/etc).
leaked=$(
	unset WORK_ENV DOT_ENVIRONMENT DOT_NAME
	tmp=$(mktemp -d)
	printf 'DOT_ENVIRONMENT="work"\nDOT_NAME="LEAKED"\n' >"$tmp/.dotconfig"
	# shellcheck disable=SC1091
	source "$SCRIPT_DIR/dot_env.sh" >/dev/null 2>&1
	dot_resolve_env "$tmp/.dotconfig" >/dev/null
	echo "${DOT_NAME:-clean}"
	rm -rf "$tmp"
)
if [[ "$leaked" == "clean" ]]; then
	echo "  ✓ .dotconfig vars don't leak into the caller"
	pass=$((pass + 1))
else
	echo "  ✗ .dotconfig leaked DOT_NAME=$leaked into the caller"
	fail=$((fail + 1))
fi

echo
if [[ $fail -eq 0 ]]; then
	echo "All $pass tests passed"
	exit 0
fi
echo "$fail of $((pass + fail)) tests FAILED"
exit 1
