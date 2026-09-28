---
name: 1337x-magnet
description: Find a torrent magnet link (plus infohash, size, seeders/leechers, description) on 1337x.to. Use when the user asks for a magnet, a torrent, a repack, or "1337x" for any title — games, movies, TV, music, software. Triggers include "get me a magnet", "find the torrent for X", "1337x X", "download X torrent", "find infohash for X", "what's the magnet for X".
---

# 1337x magnet lookup

Goal: given a title, return a **magnet URI** plus infohash, size, seeders/leechers, and
the source URL.

## Use the script first

`scripts/1337x-magnet.sh` does the whole thing — attach, search, pick, extract — and is
the normal path. Do not hand-drive `agent-browser` unless the script reports a problem.

Also symlinked onto PATH as `1337x-magnet` from `~/.local/bin`.

```bash
S=~/.claude/skills/1337x-magnet/scripts/1337x-magnet.sh

$S --check                                  # is a browser attached?
$S "Skyrim Special Edition FitGirl"         # search + auto-pick, prints JSON
$S "Skyrim" --filter fitgirl                # narrow candidates by regex
$S "Skyrim" --filter fitgirl --list         # list candidates, fetch nothing
$S --id 4196293                             # re-fetch a known torrent id
```

Output is one JSON object: `title`, `magnet`, `infohash`, `size`, `uploaded_by`,
`downloads`, `last_checked`, `date_uploaded`, `seeders`, `leechers`, `s_l` (combined
`"N se / N le"`), `language`, `description` (first ~1500 chars), `url`, `searched`.

**Report the magnet to the user.** Show the infohash, size, and seed count next to it —
a magnet with no seeder count is not actionable. If several versions match, run `--list`
and let the user choose rather than silently picking the first.

### Env vars

| Var | Default | Notes |
|---|---|---|
| `CDP_PORT` | `9222` | must be a **real** browser, not an agent-browser-launched one |

## The hard part is Cloudflare, not the search

1337x.to sits behind a managed challenge that a **fresh automated Chrome never clears** —
it re-issues a new Ray ID every check rather than granting `cf_clearance`. A real browser
profile that has visited the site before usually clears it instantly.

The script exits with code `3` and an explanation when it's still being challenged. Fix it
by attaching to a real profile (below), or have the user pass the challenge by hand in
that browser and rerun.

**1337x.to only — never fall back to a mirror (`1337x.la` etc.).** The user requires
the `.to` origin; if Cloudflare cannot be cleared, stop and say so.

### Attaching a real browser

The browser must already be running with a CDP port; it usually is not.

```bash
osascript -e 'tell application "Brave Browser" to quit'
open -na "Brave Browser" --args --remote-debugging-port=9222 --restore-last-session
curl -s http://127.0.0.1:9222/json/version    # verify before continuing
```

**Get explicit user consent before relaunching someone's browser.** A
`--remote-debugging-port` on a real profile lets any local process drive that browser —
tabs, cookies, authenticated sessions. Remind them to relaunch without the flag
afterwards.

Verify the bundle name with `ls /Applications` first; guessing wrong gives
`Unable to find application named ...`.

## Manual fallback

If the script can't run, the underlying sequence is:

```bash
T="agent-browser --cdp 9222 --pin-tab"        # --pin-tab is mandatory
$T tab new "https://1337x.to/home/"
$T snapshot -i                                # the searchbox ref
$T fill @eNN "skyrim"; $T press Enter         # real keypress; form.submit() is ignored
$T eval "Array.from(document.querySelectorAll('a'))
          .map(a=>a.textContent.trim()+' | '+a.href)
          .filter(s=>/torrent\/\d+/.test(s) && /skyrim/i.test(s)).join('\n')"
```

Then open the chosen torrent and pull the magnet with
`document.querySelector('a[href^=magnet]').href`.

## Pitfalls

Each of these cost real debugging time — don't rediscover them.

- **`--pin-tab` is required on every command.** Without it each invocation binds the
  *first* page tab, so a freshly opened tab is invisible and every `eval` reads
  `about:blank`.
- **Never call `tab list` mid-script.** It re-binds the pin to the first tab. Use
  `tab new <url>` and retry.
- **`agent-browser connect 9222` does not attach to your browser** — it launches its own.
  Use the global `--cdp <port>` flag on each command.
- **`agent-browser eval` escapes newlines as literal `\n`** and wraps results in quotes.
  Strip both before `head -1` or you get the whole result set as one line. The script's
  `js`/`jsl` helpers do this.
- **The 1337x searchbox ignores multi-word queries and returns nothing.** Reduce to one
  distinctive token and filter rows in JS. "Skyrim Special Edition FitGirl" → `skyrim`.
  A long query returning zero results is this bug, not a missing torrent.
- **`--id` does not work on its own** — `/torrent/<id>/` 404s, and the id isn't linked
  from home. Search by title and read the id off the result URL.
- **Don't loop on a stuck challenge.** Each poll re-issues a Ray ID; you are being
  fingerprinted, not waiting. Switch approach.
- **Always extract the magnet via `a[href^=magnet]`.** Hand-assembling one from the
  infohash silently drops the tracker list.

## Legal

These are user-requested pointers into a public torrent index. Return the infohash and
metadata the site already publishes; do not fetch the payload, and do not build anything
that bulk-scrapes or republishes the index.
