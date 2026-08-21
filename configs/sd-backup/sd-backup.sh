#!/bin/bash
#
# Triggered by launchd (StartOnMount) whenever ANY volume mounts. Detects an
# SD card (a removable volume with a DCIM/ dir), and if it holds photos that
# aren't on the NAS yet, asks whether to copy them to tank01.
#
# Idempotent by construction: a file's destination is a pure function of its
# name + mtime, so the same photo always maps to the same path. Files already
# at their destination are never re-read, re-copied, or even counted — if
# nothing is new, this exits silently without prompting at all.
#
# Never deletes anything from the card.
#
# Usage:
#   sd-backup.sh                 real run (launchd calls this with no args)
#   sd-backup.sh --plan CARD DST print the src<TAB>dst copy plan, copy nothing

set -uo pipefail

DEST_ROOT="${SD_BACKUP_DEST:-/Volumes/tank01/Photos and Videos/Camera Imports}"

# Media only. Fuji also writes .CTG catalog files into DCIM/ — not photos.
MEDIA_EXT=(jpg jpeg png heic heif raf dng cr2 cr3 nef arw orf rw2 mov mp4 avi m4v)

# --- helpers ----------------------------------------------------------------

# launchd swallows everything that isn't logged; the plist points stdout at
# /tmp/sd-backup.log, so this is the only way to see why a run did nothing.
# Writes to stderr (also captured by the log) so that logging from inside a
# function can never end up inside a $(...) capture of that function's output.
dbg() {
  [ -n "${SD_BACKUP_QUIET:-}" ] && return 0
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
}

fsize() { stat -f '%z' "$1" 2>/dev/null || echo -1; }

notify() {
  [ -n "${SD_BACKUP_QUIET:-}" ] && return 0
  osascript -e "display notification \"$1\" with title \"SD Backup\"" >/dev/null 2>&1
}

# A dialog that has to be dismissed, for the end of the run. A notification is
# too easy to miss, and "the card is safe to pull" is worth actually reading.
inform() {
  [ -n "${SD_BACKUP_QUIET:-}" ] && return 0
  osascript \
    -e 'on run {msg}' \
    -e 'tell application "System Events" to activate' \
    -e 'display dialog msg with title "SD Backup" buttons {"OK"} default button "OK" with icon note giving up after 600' \
    -e 'end run' "$1" >/dev/null 2>&1
}

# Ask yes/no. Returns 0 for yes, 1 for anything else (No, Escape, timeout).
# Reports why on failure — "the dialog never appeared" and "you clicked Not
# now" are indistinguishable from the exit code alone.
ask() {
  local out rc
  out=$(osascript \
    -e 'on run {msg}' \
    -e 'tell application "System Events" to activate' \
    -e 'set r to display dialog msg with title "SD Backup" buttons {"Not now", "Back up"} default button "Back up" with icon note giving up after 120' \
    -e 'if button returned of r is not "Back up" then error number -128' \
    -e 'end run' "$1" 2>&1)
  rc=$?
  [ "$rc" -eq 0 ] || dbg "dialog rc=$rc: ${out:-no output}"
  return "$rc"
}

# First /Volumes entry that looks like a camera card. The NAS is skipped
# explicitly: it mounts *during* our own run and has no DCIM anyway.
find_card() {
  local v
  for v in /Volumes/*; do
    [ -d "$v/DCIM" ] || continue
    [ "$v" = "${DEST_ROOT%%/Photos}" ] && continue
    printf '%s\n' "$v"
    return 0
  done
  return 1
}

# NAS_SMB_URL lives in ~/.zshrc-sec (this repo is public and bans real IPs).
# launchd jobs get a minimal env, so read the file rather than expect the var.
#
# Waits for the SHARE, then creates the destination folder. Testing for the
# destination folder itself conflates "NAS is unreachable" with "that folder
# doesn't exist yet" — which reports a mount failure on a mounted share and
# waits for a directory nothing will ever create.
ensure_dest() {
  local mount_point="/Volumes/$(printf '%s' "${DEST_ROOT#/Volumes/}" | cut -d/ -f1)"

  if [ ! -d "$mount_point" ]; then
    local url i=0
    url="${NAS_SMB_URL:-$(sed -n 's/^[[:space:]]*export NAS_SMB_URL="\(.*\)"$/\1/p' \
      "$HOME/.zshrc-sec" 2>/dev/null | tail -1)}"
    [ -n "$url" ] || { dbg "no NAS_SMB_URL in ~/.zshrc-sec"; return 1; }
    dbg "mounting $mount_point"
    open "$url"
    until [ -d "$mount_point" ] || [ $((i++)) -gt 30 ]; do sleep 0.5; done
    [ -d "$mount_point" ] || { dbg "$mount_point never appeared"; return 1; }
  fi

  mkdir -p "$DEST_ROOT" 2>/dev/null || { dbg "cannot create $DEST_ROOT"; return 1; }
  [ -d "$DEST_ROOT" ]
}

# Every media file on the card, sorted. Single definition of "is this a photo",
# shared by the planner and the eraser — if they disagreed, erase could delete
# something the plan never copied.
media_files() {
  local find_args=() ext first=1
  for ext in "${MEDIA_EXT[@]}"; do
    ((first)) && first=0 || find_args+=(-o)
    find_args+=(-iname "*.$ext")
  done
  find "$1/DCIM" -type f \( "${find_args[@]}" \) 2>/dev/null | sort
}

# Emit "src<TAB>dst" for every file that still needs copying.
#   $1 card root   $2 destination root
# Destination is $dst/YYYY/YYYY-MM/<name>, dated from the file's mtime (the
# Fuji sets mtime to capture time; there's no exiftool on this box).
plan() {
  local card="$1" dst="$2"
  local src base ymd y ym target ssize stem sfx n cand
  while IFS= read -r src; do
    base="${src##*/}"
    ymd=$(stat -f '%Sm' -t '%Y %Y-%m' "$src" 2>/dev/null) || continue
    y="${ymd%% *}"
    ym="${ymd##* }"
    target="$dst/$y/$ym/$base"
    ssize=$(fsize "$src")

    if [ ! -e "$target" ]; then
      printf '%s\t%s\n' "$src" "$target"
      continue
    fi
    # Same name already there. Same size => already backed up, skip silently.
    [ "$(fsize "$target")" = "$ssize" ] && continue

    # Different size: a genuinely different photo. Fuji reuses filenames after
    # DSCF9999, so copying over it (or skipping it) would lose a photo. Walk
    # to the first free -N slot, treating a same-size -N as already backed up.
    stem="${base%.*}"
    sfx="${base##*.}"
    n=1
    while :; do
      cand="$dst/$y/$ym/$stem-$n.$sfx"
      [ -e "$cand" ] || break
      [ "$(fsize "$cand")" = "$ssize" ] && { cand=""; break; }
      n=$((n + 1))
    done
    [ -n "$cand" ] && printf '%s\t%s\n' "$src" "$cand"
  done < <(media_files "$card")
}

# Delete the media files from a card. Callers MUST have confirmed that a fresh
# plan is empty first — that is the proof every one of these files exists at its
# destination with a matching size. Only files media_files() recognises are
# touched, so camera housekeeping (.CTG catalogs, FFDB, System Volume
# Information) and the DCIM folder structure survive, which is what the camera
# expects to find. Prints the number deleted.
erase_card() {
  local f n=0 failed=0
  while IFS= read -r f; do
    if rm -f "$f" 2>/dev/null; then n=$((n + 1)); else failed=$((failed + 1)); fi
  done < <(media_files "$1")
  [ "$failed" -eq 0 ] || dbg "erase: $failed file(s) could not be deleted"
  printf '%s\n' "$n"
}

# Execute a plan. $1 plan file, $2 card root, $3 scratch dir.
# Groups by destination dir so this is one rsync per month, not per file.
# Renames (the -N collision cases) can't be batched — rsync's --files-from
# keeps the source basename — so those go one at a time with an explicit
# destination file path.
#
# Writes the newest destination dir to $tmp/newest rather than echoing it: a
# return value on stdout would silently absorb any logging added inside this
# function, which is exactly how the Finder-open broke once already.
copy_plan() {
  local pf="$1" card="$2" tmp="$3" rc=0
  local src dst ddir renames=()

  while IFS=$'\t' read -r src dst; do
    ddir="${dst%/*}"
    if [ "${src##*/}" = "${dst##*/}" ]; then
      printf '%s\n' "${src#"$card"/DCIM/}" >> "$tmp/$(echo "$ddir" | tr '/' '_').list"
      printf '%s\n' "$ddir" >> "$tmp/dirs"
    else
      renames+=("$src|$dst")
    fi
  done < "$pf"

  # One batch per month, so month boundaries double as progress checkpoints —
  # a multi-GB copy with no feedback is indistinguishable from a hung one.
  local total done_n=0 list n
  total=$(wc -l < "$pf" | tr -d ' ')

  # --partial so an interrupted multi-GB transfer resumes instead of restarting.
  # --modify-window=2 because the card is FAT32 (2-second mtime granularity),
  # which otherwise looks "changed" to rsync against SMB on every single run.
  while IFS= read -r ddir; do
    list="$tmp/$(echo "$ddir" | tr '/' '_').list"
    n=$(wc -l < "$list" | tr -d ' ')
    # Braces are load-bearing: "$n…" makes bash read the ellipsis as part of
    # the variable name, which is an unbound-variable abort under `set -u`.
    notify "${ddir##*/}: copying ${n} files (${done_n} of ${total} done)"
    mkdir -p "$ddir" || { rc=1; continue; }
    rsync -a --no-relative --partial --modify-window=2 \
      --files-from="$list" "$card/DCIM/" "$ddir/" || rc=1
    done_n=$((done_n + n))
    dbg "  $ddir: $n file(s) — $done_n/$total"
  done < <(sort -u "$tmp/dirs" 2>/dev/null)

  local r
  for r in ${renames+"${renames[@]}"}; do
    src="${r%%|*}"
    dst="${r#*|}"
    mkdir -p "${dst%/*}" || { rc=1; continue; }
    rsync -a --partial "$src" "$dst" || rc=1
  done

  sort -u "$tmp/dirs" 2>/dev/null | tail -1 > "$tmp/newest"
  return "$rc"
}

# --- test hooks -------------------------------------------------------------

if [ "${1:-}" = "--plan" ]; then
  plan "$2" "$3"
  exit 0
fi

if [ "${1:-}" = "--erase" ]; then
  # $2 card root. Deletes unconditionally — the safety gate (a fresh plan
  # coming back empty) lives in the real run, so this hook exists only so the
  # deletion itself can be tested without a NAS.
  SD_BACKUP_QUIET=1
  erase_card "$2"
  exit 0
fi

if [ "${1:-}" = "--copy" ]; then
  # $2 plan file, $3 card root, $4 optional scratch dir (kept, so a test can
  # read back $4/newest — the path handed to Finder at the end of a real run)
  SD_BACKUP_QUIET=1 # tests must not fire desktop notifications
  if [ -n "${4:-}" ]; then
    scratch="$4"
    mkdir -p "$scratch"
  else
    scratch=$(mktemp -d)
    trap 'rm -rf "$scratch"' EXIT
  fi
  copy_plan "$2" "$3" "$scratch"
  exit $?
fi

# --- relay (default mode — this is what launchd runs) ------------------------
#
# macOS TCC does not let a launchd agent read a removable volume, and it never
# prompts for one: background jobs have no UI context, so the denial is silent
# and permanent. It blocks readdir but still allows stat, so the agent can
# _detect_ a card it cannot _read_.
#
# An app bundle does get a TCC identity, and a child process inherits the
# identity of the app responsible for it. So the agent only detects, and hands
# the real work to SDBackup.app (built by script/sd-backup/mac/setup.sh), which
# re-enters this script with --run. Verified: from the same launchd agent, a
# direct read of the card fails with EPERM while the applet's read succeeds.

LOCK="/tmp/sd-backup.lock"
APP="${SD_BACKUP_APP:-$HOME/Applications/SDBackup.app}"

if [ "${1:-}" != "--run" ]; then
  dbg "woke on mount; scanning /Volumes"
  [ -d "$LOCK" ] && { dbg "a backup is already in flight — done"; exit 0; }
  CARD=$(find_card) || { dbg "no card (no volume with a DCIM/) — done"; exit 0; }
  dbg "card: $CARD — handing off to $APP (this agent cannot read the card)"
  open -a "$APP" || {
    dbg "could not launch $APP — re-run script/sd-backup/mac/setup.sh"
    notify "SD card found, but SDBackup.app is missing — nothing copied."
    exit 1
  }
  exit 0
fi

# --- real run (under the applet, where the card is readable) -----------------

# The applet captures stdout instead of showing it, so this half has nowhere to
# report from. Append to the same log the agent writes, or a failed run leaves
# no trace anywhere.
exec >> /tmp/sd-backup.log 2>&1

# StartOnMount fires for every mount, and mounting the NAS below would
# re-trigger this script. mkdir is the atomic test-and-set.
# A kill -9 would strand the lock and silently disable the feature forever,
# so anything older than a plausible transfer (6h) is treated as dead.
[ -n "$(find "$LOCK" -maxdepth 0 -mmin +360 2>/dev/null)" ] && rm -rf "$LOCK"
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rm -rf "$LOCK" "${TMP:-}"' EXIT

dbg "run: scanning for a card"
CARD=$(find_card) || { dbg "no card — done"; exit 0; }

# Reaching here without read access means we are not running under the applet's
# TCC identity — the one failure that otherwise looks exactly like "no photos".
if ! ls "$CARD/DCIM" >/dev/null 2>&1; then
  dbg "cannot read $CARD/DCIM even under the applet"
  notify "Can't read the card. Grant SDBackup Removable Volumes access in System Settings › Privacy & Security › Files and Folders."
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_RemovableVolume" 2>/dev/null
  exit 1
fi

TMP=$(mktemp -d)
PLAN="$TMP/plan"

plan "$CARD" "$DEST_ROOT" > "$PLAN"
COUNT=$(wc -l < "$PLAN" | tr -d ' ')
dbg "$COUNT file(s) not yet on $DEST_ROOT"
[ "$COUNT" -gt 0 ] || exit 0 # nothing new — stay silent, don't nag

BYTES=$(cut -f1 "$PLAN" | tr '\n' '\0' | xargs -0 stat -f '%z' 2>/dev/null |
  awk '{s+=$1} END {print s+0}')
HUMAN=$(awk -v b="$BYTES" 'BEGIN {
  split("B KB MB GB TB", u, " "); i = 1
  while (b >= 1024 && i < 5) { b /= 1024; i++ }
  printf (i > 2 ? "%.1f %s" : "%d %s"), b, u[i]
}')

dbg "prompting for $COUNT files ($HUMAN)"
ask "Back up $COUNT new photos ($HUMAN) from \"${CARD##*/}\" to tank01?" || {
  dbg "declined (or dialog unavailable) — nothing copied"
  exit 0
}

if ! ensure_dest; then
  dbg "could not reach $DEST_ROOT"
  notify "Could not mount tank01 — nothing was copied."
  exit 1
fi
dbg "destination ready: $DEST_ROOT"

notify "Copying $COUNT photos ($HUMAN) to tank01…"

FAILED=0
copy_plan "$PLAN" "$CARD" "$TMP" || FAILED=1
NEWEST=$(cat "$TMP/newest" 2>/dev/null)
[ -n "$NEWEST" ] || NEWEST="$DEST_ROOT"

if [ "$FAILED" -ne 0 ]; then
  dbg "one or more rsync calls failed"
  notify "Finished with errors — some photos may not have copied. Card untouched."
  open "$NEWEST"
  exit 1
fi

dbg "copied $COUNT file(s) ($HUMAN); newest dir $NEWEST"
notify "Backed up $COUNT photos ($HUMAN)."
open "$NEWEST" # look at them before deciding what to do with the card

# --- offer to clear the card ------------------------------------------------
#
# The gate is a fresh plan coming back EMPTY. plan() emits a file only when it
# is missing from the destination or differs in size, so an empty plan is proof
# that every media file on this card is on the NAS at its full size. Anything
# else — a failed transfer, a rename collision left unresolved, a file added
# while we copied — leaves a row here and the offer is never made.
plan "$CARD" "$DEST_ROOT" > "$TMP/remaining"
REMAINING=$(wc -l < "$TMP/remaining" | tr -d ' ')

if [ "$REMAINING" -ne 0 ]; then
  dbg "not offering to clear: $REMAINING file(s) still not verified on the NAS"
  exit 0
fi

TOTAL_ON_CARD=$(media_files "$CARD" | wc -l | tr -d ' ')
dbg "all $TOTAL_ON_CARD file(s) on the card verified present on the NAS"

# Default button is the non-destructive one, so a stray Return cannot wipe a
# card. Escape/timeout falls through to keeping everything.
CHOICE=$(osascript \
  -e 'on run {msg}' \
  -e 'tell application "System Events" to activate' \
  -e 'set r to display dialog msg with title "SD Backup" buttons {"Erase card", "Keep", "Open card"} default button "Open card" with icon caution giving up after 300' \
  -e 'return button returned of r' \
  -e 'end run' \
  "All $TOTAL_ON_CARD photos are verified on tank01. Clear the card?" 2>/dev/null)

case "$CHOICE" in
"Open card")
  dbg "opening card in Finder for manual deletion"
  open "$CARD/DCIM"
  ;;
"Erase card")
  DELETED=$(erase_card "$CARD")
  dbg "erased $DELETED file(s) from $CARD"

  # Eject BEFORE saying it is safe to pull. Deleting over USB leaves writes in
  # flight, and an unmounted card is the only state where yanking it cannot
  # corrupt the filesystem — so the all-clear is only honest after this.
  if diskutil eject "$CARD" >/dev/null 2>&1; then
    dbg "ejected $CARD"
    inform "Backed up $COUNT photos ($HUMAN) to tank01.

Erased $DELETED from the card and ejected it — safe to remove."
  else
    dbg "eject failed for $CARD"
    inform "Backed up $COUNT photos ($HUMAN) to tank01 and erased $DELETED from the card.

The card could NOT be ejected — eject it in Finder before removing it."
  fi
  ;;
*)
  dbg "card left as-is (${CHOICE:-no answer})"
  ;;
esac

exit 0
