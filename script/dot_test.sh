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

# `dot run` must never stop at link_file's Override/Backup/Skip prompt.
mkdir -p "$FIXTURE/script/git" "$FIXTURE/home"
printf '#!/bin/bash\necho "mode=${DOT_SYMLINK_MODE:-unset}"\n' >"$FIXTURE/script/git/setup.sh"
output=$(cd "$FIXTURE" && env -u DOT_SYMLINK_MODE HOME="$FIXTURE/home" ./bin/dot run git 2>&1)
if [[ "$output" == *"mode=backup"* ]]; then
	echo "✓ dot run exports a non-interactive DOT_SYMLINK_MODE"
else
	echo "✗ dot run left link_file interactive"
	echo "$output"
	exit 1
fi

# --- system detection ---------------------------------------------------------
# bin/dot runs its main flow when sourced, so lift only the functions under test.
dotfilesDirectory="$REPO_ROOT"
eval "$(sed -n '/^detect_system()/,/^}/p' "$REPO_ROOT/bin/dot")"
eval "$(sed -n '/^get_available_installations()/,/^}/p' "$REPO_ROOT/bin/dot")"
eval "$(sed -n '/^auto_select_installation()/,/^}/p' "$REPO_ROOT/bin/dot")"

# expect_profile <description> <expected installer> <os-release body> [omarchy dir]
expect_profile() {
	local got
	printf '%s\n' "$3" >"$FIXTURE/os-release"
	got=$(OSTYPE=linux-gnu DOT_OS_RELEASE="$FIXTURE/os-release" DOT_OMARCHY_DIR="${4:-$FIXTURE/no-omarchy}" auto_select_installation)
	if [[ "$got" == "$2" ]]; then
		echo "✓ $1 → ${2:-no profile}"
	else
		echo "✗ $1: expected '${2:-no profile}', got '$got'"
		exit 1
	fi
}
mkdir -p "$FIXTURE/omarchy"
expect_profile "Arch" linux_arch 'ID=arch'
expect_profile "Omarchy (Arch + its install dir)" linux_omarchy 'ID=arch' "$FIXTURE/omarchy"
expect_profile "Arch derivative via ID_LIKE" linux_arch $'ID=cachyos\nID_LIKE=arch'
expect_profile "Debian (the LXC)" linux_server 'ID=debian'
expect_profile "Ubuntu" linux_server $'ID=ubuntu\nID_LIKE=debian'
expect_profile "Debian derivative via ID_LIKE" linux_server $'ID=linuxmint\nID_LIKE="ubuntu debian"'
expect_profile "unknown distro is not guessed" "" 'ID=alpine'
expect_profile "Fedora (unmaintained profile) is not auto-selected" "" 'ID=fedora'

# os-release also defines NAME/VERSION; reading it must not leak them into dot.
NAME=keep
printf 'ID=arch\nNAME="Arch Linux"\n' >"$FIXTURE/os-release"
OSTYPE=linux-gnu DOT_OS_RELEASE="$FIXTURE/os-release" detect_system >/dev/null
if [[ "$NAME" == keep ]]; then
	echo "✓ detect_system does not leak os-release variables"
else
	echo "✗ detect_system overwrote NAME with '$NAME'"
	exit 1
fi

# --- every profile is runnable --------------------------------------------------
# A component listed in a *_components.sh without a setup.sh aborts that install.
missing=$(
	for f in "$REPO_ROOT"/script/*_components.sh; do
		(
			source "$f" || true
			for c in "${component_installation[@]}"; do
				[ -f "$REPO_ROOT/script/$c/setup.sh" ] || echo "$(basename "$f"): no script/$c/setup.sh"
			done
		)
	done
)
if [[ -z "$missing" ]]; then
	echo "✓ every component in every profile has a setup.sh"
else
	echo "✗ profiles list components that cannot run"
	echo "$missing"
	exit 1
fi

echo "All 17 tests passed"
