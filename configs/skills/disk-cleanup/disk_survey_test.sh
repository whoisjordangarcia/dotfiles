#!/usr/bin/env bash
# Regression test for disk-survey — drives it against a fixture tree, never the real disk.
#
# What must never break:
#   - it is READ-ONLY (nothing in the fixture may be removed or changed),
#   - a candidate with a symlink pointing into it, or a process running inside it, is never labelled safe,
#   - a build dir that is not git-ignored is not labelled safe.
#
# Run: bash configs/skills/disk-cleanup/disk_survey_test.sh
set -uo pipefail

DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SUT="$DIR/disk-survey"
TMP=$(mktemp -d)
BG_PID=""
BG2_PID=""
trap '[ -n "$BG_PID" ] && kill "$BG_PID" 2>/dev/null; [ -n "$BG2_PID" ] && pkill -P "$BG2_PID" 2>/dev/null; [ -n "$BG2_PID" ] && kill "$BG2_PID" 2>/dev/null; rm -rf "$TMP"' EXIT
pass=0 fail=0

check() { # check <description> <exit-code>
	if [ "$2" -eq 0 ]; then
		printf '  \033[32m✓\033[0m %s\n' "$1"
		pass=$((pass + 1))
	else
		printf '  \033[31m✗\033[0m %s\n' "$1"
		fail=$((fail + 1))
	fi
}

if ! command -v python3 >/dev/null 2>&1; then
	echo "python3 missing: skipped"
	exit 77
fi

mkfile() { # mkfile <path> <kilobytes>
	mkdir -p "$(dirname "$1")"
	dd if=/dev/zero of="$1" bs=1024 count="$2" 2>/dev/null
}

# --- fixture ---------------------------------------------------------------
ROOT="$TMP/dev"
HOME_FIX="$TMP/home"
mkdir -p "$ROOT" "$HOME_FIX"

# 1. a clean cargo project: ignored target, nothing pointing into it  -> safe
mkdir -p "$ROOT/clean"
printf '[package]\nname="clean"\n' >"$ROOT/clean/Cargo.toml"
printf 'target\n' >"$ROOT/clean/.gitignore"
git -C "$ROOT/clean" init -q 2>/dev/null
mkfile "$ROOT/clean/target/debug/big.bin" 4096

# 2. a cargo project whose target has a symlink pointing into it          -> caution
mkdir -p "$ROOT/linked"
printf '[package]\nname="linked"\n' >"$ROOT/linked/Cargo.toml"
printf 'target\n' >"$ROOT/linked/.gitignore"
git -C "$ROOT/linked" init -q 2>/dev/null
mkfile "$ROOT/linked/target/keep/data.bin" 3072
mkdir -p "$ROOT/consumer"
ln -s "$ROOT/linked/target/keep" "$ROOT/consumer/dep"

# 3. a cargo project whose target is NOT git-ignored                       -> caution
mkdir -p "$ROOT/unignored"
printf '[package]\nname="unignored"\n' >"$ROOT/unignored/Cargo.toml"
git -C "$ROOT/unignored" init -q 2>/dev/null
mkfile "$ROOT/unignored/target/x.bin" 2048

# 4. a node project, ignored node_modules                                   -> safe
mkdir -p "$ROOT/web"
printf '{"name":"web"}\n' >"$ROOT/web/package.json"
printf 'node_modules\n' >"$ROOT/web/.gitignore"
git -C "$ROOT/web" init -q 2>/dev/null
mkfile "$ROOT/web/node_modules/pkg/index.js" 1024

# 5. a SwiftPM project, ignored .build                                      -> safe
mkdir -p "$ROOT/app"
printf '// swift-tools-version:5.9\n' >"$ROOT/app/Package.swift"
printf '.build\n' >"$ROOT/app/.gitignore"
git -C "$ROOT/app" init -q 2>/dev/null
mkfile "$ROOT/app/.build/debug/obj.o" 1536

# 6. a project with a process running inside it                             -> caution
mkdir -p "$ROOT/busy"
printf '[package]\nname="busy"\n' >"$ROOT/busy/Cargo.toml"
printf 'target\n' >"$ROOT/busy/.gitignore"
git -C "$ROOT/busy" init -q 2>/dev/null
mkfile "$ROOT/busy/target/debug/b.bin" 1024
(cd "$ROOT/busy" && exec sleep 120) &
BG_PID=$!

# 6b. an Xcode project: build dirs have no marker file of their own, the .xcodeproj next to them is the marker
mkdir -p "$ROOT/xcapp/App.xcodeproj"
printf 'build-sim\nbuild\n' >"$ROOT/xcapp/.gitignore"
git -C "$ROOT/xcapp" init -q 2>/dev/null
mkfile "$ROOT/xcapp/build-sim/Products/app.bin" 2048
mkfile "$ROOT/xcapp/Sources/keep.swift" 64 # real source next to it: never listed

# 6c. a cache that a process RUNS FROM (its command line names a path inside it) while its cwd is elsewhere
mkdir -p "$TMP/home/.cache/livecache"
printf '#!/bin/sh\nsleep 120\n' >"$TMP/home/.cache/livecache/run.sh"
mkfile "$TMP/home/.cache/livecache/blob" 2048
(cd / && exec sh "$TMP/home/.cache/livecache/run.sh") &
BG2_PID=$!

# 7. a vendored dir that must never be listed
mkfile "$ROOT/clean/vendor/ghostty/src.txt" 2048

# 8. user-level caches in the fake home
mkfile "$HOME_FIX/.cargo/registry/cache/crate.crate" 2048
mkfile "$HOME_FIX/.cache/zig/blob" 1024
mkfile "$HOME_FIX/.cache/uv/wheels/w.whl" 2048        # not in the explicit list: found by the generic ~/.cache scan
mkfile "$HOME_FIX/Library/Caches/SomeApp/blob" 1024  # generic ~/Library/Caches scan

before=$(find "$TMP" -type f -o -type l | sort | wc -l | tr -d ' ')
sleep 0.3 # let the background process settle in its cwd

# --- the tests -------------------------------------------------------------
echo "disk-survey"

JSON=$(DISK_SURVEY_HOME="$HOME_FIX" DISK_SURVEY_TMP="$TMP/none" python3 "$SUT" --min-kb 0 --root "$ROOT" --json 2>/dev/null)
rc=$?
check "runs and exits 0" "$rc"

field() { # field <path-suffix> <key> -> value of that key for the candidate
	printf '%s' "$JSON" | python3 -c '
import json, sys
suffix, key = sys.argv[1], sys.argv[2]
for c in json.load(sys.stdin)["candidates"]:
    if c["path"].endswith(suffix):
        v = c[key]
        print(",".join(v) if isinstance(v, list) else v)
        break
' "$1" "$2"
}

[ "$(field clean/target risk)" = "safe" ]
check "a clean ignored cargo target is safe" $?

[ "$(field clean/target kind)" = "cargo-target" ]
check "cargo target is recognised by its Cargo.toml" $?

sz=$(field clean/target kb)
[ "${sz:-0}" -ge 4000 ]
check "size is measured (>= 4000 KB for a 4 MB file)" $?

[ "$(field linked/target risk)" = "caution" ]
check "a symlink pointing into the dir makes it caution" $?
field linked/target blockers | grep -q "symlink"
check "the blocker names the symlink" $?
field linked/target blockers | grep -q "consumer/dep"
check "the blocker names where the symlink lives" $?

[ "$(field unignored/target risk)" = "caution" ]
check "a build dir that is not git-ignored is caution" $?

[ "$(field web/node_modules risk)" = "safe" ]
check "an ignored node_modules next to package.json is safe" $?

[ "$(field app/.build kind)" = "swiftpm-build" ]
check "SwiftPM .build is recognised by Package.swift" $?

[ "$(field busy/target risk)" = "caution" ]
check "a running process inside the project makes it caution" $?
field busy/target blockers | grep -qi "process"
check "the blocker says a process is running there" $?

[ "$(field xcapp/build-sim kind)" = "xcode-build" ]
check "an Xcode project's build-sim dir is found via its .xcodeproj" $?
[ "$(field xcapp/build-sim risk)" = "safe" ]
check "an ignored Xcode build dir is safe" $?
printf '%s' "$JSON" | grep -q 'xcapp/Sources'
[ $? -ne 0 ]
check "source directories next to build dirs are never listed" $?

printf '%s' "$JSON" | python3 -c '
import json, sys
c = {x["path"].split("/home/")[-1]: x for x in json.load(sys.stdin)["candidates"]}
ok = c.get(".cache/uv", {}).get("kind") == "user-cache" and c.get(".cache/uv", {}).get("risk") == "safe"
ok = ok and c.get("Library/Caches/SomeApp", {}).get("kind") == "user-cache"
sys.exit(0 if ok else 1)
'
check "unlisted caches under ~/.cache and ~/Library/Caches are found generically as user-cache" $?

printf '%s' "$JSON" | python3 -c '
import json, sys
paths = [x["path"] for x in json.load(sys.stdin)["candidates"]]
sys.exit(0 if len(paths) == len(set(paths)) and not any(p.endswith(".cache/zig") and sum(q.endswith(".cache/zig") for q in paths) > 1 for p in paths) else 1)
'
check "a cache already in the explicit list is not listed twice" $?

[ "$(field .cache/livecache risk)" = "caution" ]
check "a cache that a running process executes from is caution, even with its cwd elsewhere" $?
field .cache/livecache blockers | grep -q "command line"
check "the blocker says a running command line references it" $?

printf '%s' "$JSON" | grep -q '/vendor'
[ $? -ne 0 ]
check "vendor/ directories are never listed" $?

printf '%s' "$JSON" | python3 -c '
import json, sys
paths = [c["path"] for c in json.load(sys.stdin)["candidates"]]
sys.exit(0 if any(p.endswith(".cargo/registry") for p in paths) and any(p.endswith(".cache/zig") for p in paths) else 1)
'
check "user-level caches (cargo registry, zig cache) are found under DISK_SURVEY_HOME" $?

printf '%s' "$JSON" | python3 -c '
import json, sys
d = json.load(sys.stdin)
sizes = [c["kb"] for c in d["candidates"]]
sys.exit(0 if sizes == sorted(sizes, reverse=True) else 1)
'
check "candidates are ranked largest first" $?

TEXT=$(DISK_SURVEY_HOME="$HOME_FIX" DISK_SURVEY_TMP="$TMP/none" python3 "$SUT" --min-kb 0 --root "$ROOT" 2>/dev/null)
printf '%s' "$TEXT" | grep -q "reclaim:"
check "text output prints a reclaim command per candidate" $?
printf '%s' "$TEXT" | grep -q "(not run)"
check "reclaim commands are labelled as not run" $?

LIVE=$(DISK_SURVEY_HOME="$HOME_FIX" DISK_SURVEY_TMP="$TMP/none" python3 "$SUT" --min-kb 0 --root "$ROOT" --live --count 2 --interval 0 2>/dev/null)
printf '%s' "$LIVE" | grep -q "free"
check "live mode shows the free-space header" $?
[ "$(printf '%s' "$LIVE" | grep -c "free")" -ge 2 ]
check "live mode redraws (two frames with --count 2)" $?

# live mode must notice a deletion made between frames: remove a target in the first interval
rm -rf "$ROOT/web/node_modules" # done before the run: it must show as absent, not crash
DISK_SURVEY_HOME="$HOME_FIX" DISK_SURVEY_TMP="$TMP/none" python3 "$SUT" --min-kb 0 --root "$ROOT" --live --count 1 --interval 0 >/dev/null 2>&1
check "live mode survives a candidate that disappeared" $?
mkfile "$ROOT/web/node_modules/pkg/index.js" 1024 # restore for the read-only count below

after=$(find "$TMP" -type f -o -type l | sort | wc -l | tr -d ' ')
[ "$before" = "$after" ]
check "READ-ONLY: no fixture file or link was removed or added" $?

[ -e "$ROOT/clean/target/debug/big.bin" ] && [ -e "$ROOT/consumer/dep" ]
check "READ-ONLY: the safe candidate and the symlink still exist" $?

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
