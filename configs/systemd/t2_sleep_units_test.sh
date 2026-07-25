#!/usr/bin/env bash
# Regression test for the T2 suspend/resume unit pair.
#
# Guards the two failure modes that were silent for months:
#   1. `${...}` in ExecStart eaten by systemd's own expansion (needs `$$`).
#   2. Module names that no longer exist in the installed kernel (apple_bce ->
#      t2bce_* in linux-t2 7.1).
#
# Run: bash configs/systemd/t2_sleep_units_test.sh
set -uo pipefail

DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SUSPEND="$DIR/suspend-fix-t2.service"
RESUME="$DIR/resume-fix-t2.service"
pass=0 fail=0

check() { # check <description> <condition-exit-code>
	if [ "$2" -eq 0 ]; then
		printf '  \033[32m✓\033[0m %s\n' "$1"
		pass=$((pass + 1))
	else
		printf '  \033[31m✗\033[0m %s\n' "$1"
		fail=$((fail + 1))
	fi
}

echo "T2 sleep units"

# --- 1. systemd expansion --------------------------------------------------
# Any bare `${` or `$(` in an ExecStart is expanded by systemd, not the shell.
bare=$(grep -h '^ExecStart=' "$SUSPEND" "$RESUME" | grep -cE '(^|[^$])\$[({]')
check "no unescaped \$( or \${ in ExecStart (systemd eats them)" "$([ "$bare" -eq 0 ] && echo 0 || echo 1)"

# The Touch Bar lookup must resolve a real sysfs path once un-escaped the way
# systemd hands it to bash. Extract it, undo `$$` -> `$`, run the lookup half
# only (no bConfigurationValue writes — that would cycle the Touch Bar).
lookup=$(grep -F 'idProduct' "$RESUME" | sed -e 's/^ExecStart=-*\/usr\/bin\/bash -c //' -e "s/^'//" -e "s/'$//" -e 's/\$\$/$/g')
lookup=${lookup%%; \[ -n*}
resolved=$(bash -c "$lookup; echo \"\$p\"" 2>/dev/null)
check "Touch Bar lookup resolves a sysfs path (got: ${resolved:-<empty>})" \
	"$([ -n "$resolved" ] && [ -d "$resolved" ] && echo 0 || echo 1)"

# --- 2. module names exist for the running kernel ---------------------------
# Each pair is "old-name new-name"; at least one must resolve. Everything else
# must resolve outright.
for m in brcmfmac brcmfmac_wcc hid_appletb_kbd hid_appletb_bl appletbdrm; do
	modinfo -n "$m" >/dev/null 2>&1
	check "module present: $m" $?
done
if modinfo -n apple_bce >/dev/null 2>&1 || modinfo -n t2bce_vhci >/dev/null 2>&1; then
	check "bridge driver present (apple_bce or t2bce_vhci)" 0
else
	check "bridge driver present (apple_bce or t2bce_vhci)" 1
fi

# Every module the units name must be known to *some* installed kernel,
# otherwise it's a typo rather than a deliberate cross-kernel fallback.
for m in $(grep -hoE '(rmmod -f|modprobe(  *-r)?) [a-z0-9_]+' "$SUSPEND" "$RESUME" | awk '{print $NF}' | sort -u); do
	found=1
	for k in /lib/modules/*/; do
		[ -f "$k/modules.dep" ] || continue
		grep -qE "/${m//_/[_-]}\.ko" "$k/modules.dep" && found=0 && break
	done
	check "named module exists in some installed kernel: $m" "$found"
done

# --- 3. systemd can parse them ---------------------------------------------
if command -v systemd-analyze >/dev/null 2>&1; then
	out=$(systemd-analyze verify "$SUSPEND" "$RESUME" 2>&1 | grep -vE 'Unit .* not found|command .* is not executable' )
	check "systemd-analyze verify clean${out:+ ($out)}" "$([ -z "$out" ] && echo 0 || echo 1)"
fi

echo
if [ "$fail" -eq 0 ]; then
	echo "All $pass tests passed"
else
	echo "$fail of $((pass + fail)) tests FAILED"
	exit 1
fi
