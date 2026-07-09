#!/usr/bin/env python3
"""Fetch synced lyrics from lrclib.net for every song in the local MPD
database, into rmpc's lyrics_dir (~/.local/share/rmpc/lyrics).

rmpc matches .lrc files by their [ar:]/[ti:]/[al:] tags (case-insensitive)
plus a ±5s [length:] check, so filenames don't matter and nothing needs to
be written next to the audio files on the NAS.

lrclib is free but SLOW (~5-10s per request) — run this in the background.
Idempotent: songs with an existing .lrc (or a recorded miss) are skipped.
"""
import hashlib
import json
import os
import socket
import sys
import urllib.parse
import urllib.request

LYRICS_DIR = os.path.expanduser("~/.local/share/rmpc/lyrics")
MISS_LOG = os.path.join(LYRICS_DIR, ".misses.json")  # don't re-ask lrclib for known misses


def mpd_listallinfo():
    """Read every song's tags straight from MPD's protocol."""
    s = socket.create_connection(("127.0.0.1", 6600))
    f = s.makefile("rwb")
    f.readline()  # banner
    f.write(b"listallinfo\n")
    f.flush()
    songs, cur = [], {}
    for raw in f:
        line = raw.decode("utf-8", "replace").rstrip("\n")
        if line == "OK" or line.startswith("ACK"):
            break
        key, _, val = line.partition(": ")
        if key == "file":
            if cur.get("Artist") and cur.get("Title"):
                songs.append(cur)
            cur = {"file": val}
        elif key in ("Artist", "Title", "Album", "Time"):
            cur.setdefault(key, val)
    if cur.get("Artist") and cur.get("Title"):
        songs.append(cur)
    s.close()
    return songs


def lrc_path(song):
    key = f"{song['Artist']}|{song['Title']}|{song.get('Album','')}".lower()
    return os.path.join(LYRICS_DIR, hashlib.md5(key.encode()).hexdigest() + ".lrc")


def fetch(song):
    params = urllib.parse.urlencode({
        "artist_name": song["Artist"],
        "track_name": song["Title"],
        "album_name": song.get("Album", ""),
        "duration": song.get("Time", ""),
    })
    req = urllib.request.Request(
        f"https://lrclib.net/api/get?{params}",
        headers={"User-Agent": "rmpc-lyrics-fetch (personal use)"},
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def main():
    os.makedirs(LYRICS_DIR, exist_ok=True)
    misses = set()
    if os.path.exists(MISS_LOG):
        misses = set(json.load(open(MISS_LOG)))
    songs = mpd_listallinfo()
    print(f"{len(songs)} songs in MPD database", flush=True)
    got = skipped = missed = 0
    for i, song in enumerate(songs, 1):
        dest = lrc_path(song)
        key = os.path.basename(dest)
        if os.path.exists(dest) or key in misses:
            skipped += 1
            continue
        try:
            data = fetch(song)
            synced = data.get("syncedLyrics")
        except Exception:
            synced = None
        if not synced:
            misses.add(key)
            missed += 1
        else:
            with open(dest, "w") as f:
                f.write(f"[ar:{song['Artist']}]\n[ti:{song['Title']}]\n")
                if song.get("Album"):
                    f.write(f"[al:{song['Album']}]\n")
                if song.get("Time"):
                    m, s = divmod(int(song["Time"]), 60)
                    f.write(f"[length:{m}:{s:02d}]\n")
                f.write(synced + "\n")
            got += 1
        if i % 10 == 0:
            json.dump(sorted(misses), open(MISS_LOG, "w"))
            print(f"[{i}/{len(songs)}] fetched={got} missed={missed} skipped={skipped}", flush=True)
    json.dump(sorted(misses), open(MISS_LOG, "w"))
    print(f"done: fetched={got} missed={missed} skipped={skipped}", flush=True)


if __name__ == "__main__":
    main()
