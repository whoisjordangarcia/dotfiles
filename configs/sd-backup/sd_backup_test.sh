#!/usr/bin/env bash
# Regression tests for sd-backup.sh (pure --plan hook; no card, no NAS, no
# launchd needed). The plan IS the idempotency contract — if a file is not in
# the plan it never gets copied, so these assertions pin the whole behaviour.
# Run: bash configs/sd-backup/sd_backup_test.sh
set -u

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
SUT="$SCRIPT_DIR/sd-backup.sh"

PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "✓ $desc"
        PASS=$((PASS + 1))
    else
        echo "✗ $desc"
        echo "    expected: '$expected'"
        echo "    actual:   '$actual'"
        FAIL=$((FAIL + 1))
    fi
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
CARD="$TMP/card"
DST="$TMP/dst"

# Plan, with the temp prefix stripped so assertions stay readable.
plan() { bash "$SUT" --plan "$CARD" "$DST" | sed "s|$TMP/||g"; }

# Make a card file with a fixed mtime. $1 relative path, $2 mtime, $3 content
mkfile() {
    mkdir -p "$CARD/DCIM/$(dirname "$1")"
    printf '%s' "$3" > "$CARD/DCIM/$1"
    touch -t "$2" "$CARD/DCIM/$1"
}

# Make a file already sitting on the NAS. $1 relative path, $2 content
mkdest() {
    mkdir -p "$DST/$(dirname "$1")"
    printf '%s' "$2" > "$DST/$1"
}

# --- dating and layout ------------------------------------------------------

mkfile "110_FUJI/DSCF0648.JPG" "202607181200" "photo-a"
assert_eq "new file is planned into YYYY/YYYY-MM from its mtime" \
    "card/DCIM/110_FUJI/DSCF0648.JPG	dst/2026/2026-07/DSCF0648.JPG" \
    "$(plan)"

mkfile "110_FUJI/DSCF0649.JPG" "202408271200" "photo-b"
assert_eq "each file is dated independently, not by card or by folder" \
    "card/DCIM/110_FUJI/DSCF0648.JPG	dst/2026/2026-07/DSCF0648.JPG
card/DCIM/110_FUJI/DSCF0649.JPG	dst/2024/2024-08/DSCF0649.JPG" \
    "$(plan)"

# --- idempotency ------------------------------------------------------------

mkdest "2026/2026-07/DSCF0648.JPG" "photo-a"
assert_eq "a file already at its destination is dropped from the plan" \
    "card/DCIM/110_FUJI/DSCF0649.JPG	dst/2024/2024-08/DSCF0649.JPG" \
    "$(plan)"

mkdest "2024/2024-08/DSCF0649.JPG" "photo-b"
assert_eq "re-running with everything backed up plans nothing (no prompt)" \
    "" "$(plan)"

# --- filename rollover: same name, different photo --------------------------

rm -rf "$CARD" "$DST"
mkfile "110_FUJI/DSCF0648.JPG" "202607181200" "a-different-photo-entirely"
mkdest "2026/2026-07/DSCF0648.JPG" "the-original"
assert_eq "same name + different size gets a -1 suffix, not an overwrite" \
    "card/DCIM/110_FUJI/DSCF0648.JPG	dst/2026/2026-07/DSCF0648-1.JPG" \
    "$(plan)"

mkdest "2026/2026-07/DSCF0648-1.JPG" "a-different-photo-entirely"
assert_eq "a suffixed copy is itself idempotent — no -2 on the next run" \
    "" "$(plan)"

mkfile "110_FUJI/DSCF0648.JPG" "202607181200" "yet-another-third-photo!!"
assert_eq "a third distinct photo with that name walks on to -2" \
    "card/DCIM/110_FUJI/DSCF0648.JPG	dst/2026/2026-07/DSCF0648-2.JPG" \
    "$(plan)"

# --- what counts as a photo -------------------------------------------------

rm -rf "$CARD" "$DST"
mkfile "110_FUJI/DSCF0700.JPG" "202607181200" "jpg"
mkfile "110_FUJI/DSCF0700.MOV" "202607181200" "mov"
mkfile "110_FUJI/DSCF0700.RAF" "202607181200" "raw"
mkfile "110_FUJI/FUJI0001.CTG" "202607181200" "fuji catalog file"
assert_eq "stills, video and raw are planned; the Fuji .CTG catalog is not" \
    "card/DCIM/110_FUJI/DSCF0700.JPG	dst/2026/2026-07/DSCF0700.JPG
card/DCIM/110_FUJI/DSCF0700.MOV	dst/2026/2026-07/DSCF0700.MOV
card/DCIM/110_FUJI/DSCF0700.RAF	dst/2026/2026-07/DSCF0700.RAF" \
    "$(plan)"

rm -rf "$CARD" "$DST"
mkfile "110_FUJI/lower.jpg" "202607181200" "x"
assert_eq "extension matching is case-insensitive" \
    "card/DCIM/110_FUJI/lower.jpg	dst/2026/2026-07/lower.jpg" \
    "$(plan)"

# --- empty / missing card ---------------------------------------------------

rm -rf "$CARD" "$DST"
mkdir -p "$CARD/DCIM"
assert_eq "a card with an empty DCIM plans nothing" "" "$(plan)"

rm -rf "$CARD"
assert_eq "a card that vanished mid-run plans nothing (no error output)" "" "$(plan)"

# --- the copy itself (real rsync, real files) -------------------------------
#
# The plan decides what to copy; these check that executing it actually puts
# the bytes in the right place and never destroys a photo.

run_backup() {
    bash "$SUT" --plan "$CARD" "$DST" > "$TMP/plan.tsv"
    bash "$SUT" --copy "$TMP/plan.tsv" "$CARD"
}

rm -rf "$CARD" "$DST"
mkfile "110_FUJI/DSCF0648.JPG" "202607181200" "july-photo"
mkfile "110_FUJI/DSCF0649.JPG" "202408271200" "august-photo"
mkfile "111_FUJI/DSCF0650.MOV" "202607181200" "july-video"
run_backup

assert_eq "copy lands files in their dated folders, flattening camera dirs" \
    "dst/2024/2024-08/DSCF0649.JPG
dst/2026/2026-07/DSCF0648.JPG
dst/2026/2026-07/DSCF0650.MOV" \
    "$(find "$DST" -type f | sed "s|$TMP/||" | sort)"

assert_eq "copied contents match the source" \
    "july-photo|august-photo|july-video" \
    "$(cat "$DST/2026/2026-07/DSCF0648.JPG")|$(cat "$DST/2024/2024-08/DSCF0649.JPG")|$(cat "$DST/2026/2026-07/DSCF0650.MOV")"

BEFORE=$(find "$DST" -type f -exec stat -f '%N %z %m' {} + | sort)
run_backup
assert_eq "running the whole backup again changes nothing on disk" \
    "$BEFORE" "$(find "$DST" -type f -exec stat -f '%N %z %m' {} + | sort)"

assert_eq "the card is never modified" \
    "card/DCIM/110_FUJI/DSCF0648.JPG
card/DCIM/110_FUJI/DSCF0649.JPG
card/DCIM/111_FUJI/DSCF0650.MOV" \
    "$(find "$CARD" -type f | sed "s|$TMP/||" | sort)"

# Rollover: a new card reuses DSCF0648.JPG for a different photo in the same
# month. The original must survive and the new one must still land.
mkfile "112_FUJI/DSCF0648.JPG" "202607181200" "a-completely-different-july-photo"
run_backup
assert_eq "a same-name different photo is copied alongside, not over, the original" \
    "july-photo|a-completely-different-july-photo" \
    "$(cat "$DST/2026/2026-07/DSCF0648.JPG")|$(cat "$DST/2026/2026-07/DSCF0648-1.JPG")"

run_backup
assert_eq "and that rollover copy does not duplicate on the next run" \
    "1" "$(find "$DST/2026/2026-07" -name 'DSCF0648-*' | wc -l | tr -d ' ')"

# --- clearing the card ------------------------------------------------------
#
# Deletion. The safety gate is "a fresh plan comes back empty", so the first
# assertion below is the one that actually protects the photos.

rm -rf "$CARD" "$DST"
mkfile "110_FUJI/DSCF0648.JPG" "202607181200" "photo"
mkfile "110_FUJI/DSCF0649.JPG" "202607181200" "another"
mkfile "110_FUJI/FUJI0001.CTG" "202607181200" "camera catalog"
printf 'db' > "$CARD/FFDB"

# Back up only ONE of the two photos, then confirm the gate refuses.
mkdest "2026/2026-07/DSCF0648.JPG" "photo"
assert_eq "with one photo not yet copied, the plan is non-empty (erase blocked)" \
    "card/DCIM/110_FUJI/DSCF0649.JPG	dst/2026/2026-07/DSCF0649.JPG" \
    "$(plan)"

# A truncated destination file must also block, not read as "done".
mkdest "2026/2026-07/DSCF0649.JPG" "trunc"
assert_eq "a short/truncated destination file keeps the erase gate closed" \
    "card/DCIM/110_FUJI/DSCF0649.JPG	dst/2026/2026-07/DSCF0649-1.JPG" \
    "$(plan)"

# Now back it up properly — gate opens.
mkdest "2026/2026-07/DSCF0649-1.JPG" "another"
assert_eq "once every photo is on the NAS at full size, the plan is empty" \
    "" "$(plan)"

bash "$SUT" --erase "$CARD" > /dev/null
assert_eq "erase removes the photos" \
    "" "$(find "$CARD/DCIM" -iname '*.JPG' | sed "s|$TMP/||" | sort)"
assert_eq "erase leaves camera housekeeping and the DCIM structure intact" \
    "card/DCIM/110_FUJI
card/DCIM/110_FUJI/FUJI0001.CTG
card/FFDB" \
    "$(find "$CARD" -mindepth 1 ! -name DCIM | sed "s|$TMP/||" | sort)"

# --- the folder Finder opens ------------------------------------------------
#
# This is what `open` receives at the end of a run. It regressed once by
# absorbing log output, so assert it is exactly one clean path.

rm -rf "$CARD" "$DST"
mkfile "110_FUJI/OLD.JPG" "202408271200" "old"
mkfile "110_FUJI/NEW.JPG" "202607181200" "new"
SCRATCH_TMP="$TMP/copyscratch"
rm -rf "$SCRATCH_TMP"; mkdir -p "$SCRATCH_TMP"
bash "$SUT" --plan "$CARD" "$DST" > "$TMP/plan.tsv"
bash "$SUT" --copy "$TMP/plan.tsv" "$CARD" "$SCRATCH_TMP"

assert_eq "Finder gets the newest month, as a single clean line" \
    "dst/2026/2026-07" \
    "$(sed "s|$TMP/||" "$SCRATCH_TMP/newest" 2>/dev/null)"

# --- paths with spaces ------------------------------------------------------
#
# The real destination is "…/Photos and Videos/Camera Imports" and the card
# mounts as "NO NAME", so every path in play has spaces in it.

SPACED_CARD="$TMP/my card"
SPACED_DST="$TMP/Photos and Videos/Camera Imports"
mkdir -p "$SPACED_CARD/DCIM/110 FUJI"
printf 'spaced' > "$SPACED_CARD/DCIM/110 FUJI/DSC 0001.JPG"
touch -t "202607181200" "$SPACED_CARD/DCIM/110 FUJI/DSC 0001.JPG"

bash "$SUT" --plan "$SPACED_CARD" "$SPACED_DST" > "$TMP/spaced.tsv"
assert_eq "spaces survive planning, in card path, camera dir, filename and dest" \
    "my card/DCIM/110 FUJI/DSC 0001.JPG	Photos and Videos/Camera Imports/2026/2026-07/DSC 0001.JPG" \
    "$(sed "s|$TMP/||g" "$TMP/spaced.tsv")"

bash "$SUT" --copy "$TMP/spaced.tsv" "$SPACED_CARD"
assert_eq "spaces survive the copy" \
    "spaced" "$(cat "$SPACED_DST/2026/2026-07/DSC 0001.JPG" 2>/dev/null)"

bash "$SUT" --plan "$SPACED_CARD" "$SPACED_DST" > "$TMP/spaced2.tsv"
assert_eq "and a spaced path is still idempotent on re-run" \
    "" "$(cat "$TMP/spaced2.tsv")"

echo
if [ "$FAIL" -eq 0 ]; then
    echo "All $PASS tests passed"
    exit 0
else
    echo "$FAIL of $((PASS + FAIL)) tests failed"
    exit 1
fi
