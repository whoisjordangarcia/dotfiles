#!/bin/bash
#===============================================================================
# dot_env.sh — resolve the work/personal environment, consistently, in ONE place.
#
# Sourced by script/claude/setup.sh, script/claude/sync-settings.sh and
# script/skills/setup.sh. Sourcing only DEFINES functions (repo convention for
# sourced libs — no side effects); call dot_export_env to set DOT_ENV
# ("work"|"personal") and export WORK_ENV/DOT_ENVIRONMENT to match, so sourced
# children and grandchild processes all agree.
#
# Precedence:
#   1. WORK_ENV=1                       — explicit override, wins outright.
#   2. non-empty DOT_ENVIRONMENT        — how bin/dot drives component scripts.
#   3. .dotconfig's DOT_ENVIRONMENT     — the STANDALONE install path.
#   4. personal                         — safe default (never installs work-only
#                                         plugins/skills onto a personal box).
#
# Why (2) tests DOT_ENVIRONMENT and not WORK_ENV: bin/dot exports WORK_ENV=""
# (empty, not unset) for personal, so an empty WORK_ENV carries no signal — only
# a non-empty DOT_ENVIRONMENT is authoritative there.
#
# Why (3) exists: component scripts are a documented standalone install path
# (`./script/claude/setup.sh`), where bin/dot has exported nothing. Without the
# fallback a work machine silently installs the PERSONAL config — dropping the
# touchid-gate + prod-AWS tripwires and every nest-* plugin/skill. That is a
# security regression that fails silently, so it gets a shared, tested resolver
# rather than a copy per caller.
#
# .dotconfig is `source`d (in a subshell, so it cannot clobber the caller's vars)
# rather than grepped: bin/dot writes it with `source` semantics, and a
# grep+cut '"' parse silently mis-reads an unquoted DOT_ENVIRONMENT=work and
# falls through to personal — i.e. straight back into the bug above.
#
# Sourced lib: use a private dir var so we don't clobber the caller's SCRIPT_DIR.
#===============================================================================

_DOT_ENV_LIB_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
_DOT_ENV_REPO_DIR=$(cd -- "$_DOT_ENV_LIB_DIR/../.." &>/dev/null && pwd)

# dot_resolve_env [dotconfig_path] -> echoes "work" | "personal"
# Pure: reads the environment + the given .dotconfig, writes nothing.
# The path arg exists so dot_env_test.sh can drive it against fixtures.
dot_resolve_env() {
	local dotconfig="${1:-$_DOT_ENV_REPO_DIR/.dotconfig}"
	local from_file=""

	if [[ "${WORK_ENV:-}" == "1" ]]; then
		echo "work"
		return 0
	fi
	if [[ -n "${DOT_ENVIRONMENT:-}" ]]; then
		if [[ "$DOT_ENVIRONMENT" == "work" ]]; then
			echo "work"
		else
			echo "personal"
		fi
		return 0
	fi
	if [[ -f "$dotconfig" ]]; then
		from_file=$(
			# shellcheck disable=SC1090
			source "$dotconfig" 2>/dev/null
			echo "${DOT_ENVIRONMENT:-}"
		)
		if [[ "$from_file" == "work" ]]; then
			echo "work"
			return 0
		fi
	fi
	echo "personal"
}

# dot_export_env — resolve once, then set DOT_ENV and align the exports with it.
# Call this from a setup script; then read "$DOT_ENV".
#
# Deliberately NOT run at source time: that would export WORK_ENV/DOT_ENVIRONMENT
# as a side effect of sourcing, which then feeds back into rule (1)/(2) and makes
# a later dot_resolve_env call return the already-resolved answer for any
# .dotconfig you hand it. Keeping resolution explicit keeps the function pure.
dot_export_env() {
	DOT_ENV="$(dot_resolve_env "$@")"
	export DOT_ENV
	if [[ "$DOT_ENV" == "work" ]]; then
		export WORK_ENV=1
		export DOT_ENVIRONMENT="work"
	else
		# Mirror bin/dot, which exports WORK_ENV="" (not unset) for personal.
		export WORK_ENV=""
		export DOT_ENVIRONMENT="personal"
	fi
}
