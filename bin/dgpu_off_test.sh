#!/usr/bin/env bash
# Regression test for bin/dgpu-off — drives it against fixture switch files.
#
# The one thing that must never break: it may only write OFF when the
# INTEGRATED GPU is the active client. Getting that backwards powers down the
# GPU currently driving the display.
#
# Run: bash bin/dgpu_off_test.sh
set -uo pipefail

DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SUT="$DIR/dgpu-off"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
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

# run <fixture-content> -> echoes the switch file as the script left it
run() {
	local f="$TMP/switch"
	printf '%s\n' "$1" >"$f"
	DGPU_OFF_SWITCH="$f" DGPU_OFF_RETRIES=1 bash "$SUT" >/dev/null 2>&1
	cat "$f"
}

echo "dgpu-off"

# Real layout from a MacBookPro15,1 — note DIS is index 2, and DIS-Audio is a
# separate client whose name also starts with "DIS".
IGD_ACTIVE='0:DIS-Audio: :DynOff:0000:01:00.1
1:IGD:+:Pwr:0000:00:02.0
2:DIS: :Pwr:0000:01:00.0'

DIS_ACTIVE='0:DIS-Audio: :DynPwr:0000:01:00.1
1:IGD: :Pwr:0000:00:02.0
2:DIS:+:Pwr:0000:01:00.0'

ALREADY_OFF='0:DIS-Audio: :DynOff:0000:01:00.1
1:IGD:+:Pwr:0000:00:02.0
2:DIS: :Off:0000:01:00.0'

out=$(run "$IGD_ACTIVE")
[ "$out" = "OFF" ]
check "iGPU active -> writes OFF" $?

# The safety property. In the dedicated profile the dGPU is driving the
# display; writing OFF there would cut the active GPU.
out=$(run "$DIS_ACTIVE")
[ "$out" != "OFF" ]
check "dGPU active -> does NOT write (would kill the active GPU)" $?

out=$(run "$ALREADY_OFF")
[ "$out" != "OFF" ]
check "already off -> no redundant write (idempotent on resume)" $?

# DIS-Audio is 'DynOff' while the GPU is still powered — must not be mistaken
# for the GPU being off, or the real power-off is silently skipped.
out=$(run "$IGD_ACTIVE")
[ "$out" = "OFF" ]
check "DIS-Audio DynOff not misread as the GPU being off" $?

# Missing/unreadable switch file (not a dual-GPU machine) must exit clean, not
# hang or fail the boot unit.
DGPU_OFF_SWITCH="$TMP/nope" DGPU_OFF_RETRIES=1 bash "$SUT" >/dev/null 2>&1
check "absent switch file -> exits 0 (no-op, unit stays green)" $?

echo
if [ "$fail" -eq 0 ]; then
	echo "All $pass tests passed"
else
	echo "$fail of $((pass + fail)) tests FAILED"
	exit 1
fi
