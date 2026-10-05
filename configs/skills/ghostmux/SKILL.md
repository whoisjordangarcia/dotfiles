---
name: ghostmux
description: Drive the running GhostMux terminal app from the shell — create sessions, launch agents in them, rename sessions, and organize them into groups. Use whenever the user asks to open/create/spin up ghostmux sessions or tabs, put sessions in a group, rename or close a ghostmux session, list what's running in ghostmux, fan work out across several worktrees each with its own agent, or have a recurring loop (PR checks, issue triage) open one named, grouped session per item. Triggers on "ghostmux", "new session", "new thread", "spin up N worktrees", "launch claude in a session", "a session per PR", "what's running in ghostmux".
---

# Driving GhostMux from the shell

GhostMux is a macOS terminal multiplexer. The app installs its CLI at
`~/.ghostmux/bin/ghostmux` — call it by that path unless `ghostmux` is on PATH.
Examples below write `ghostmux` for short.

**GhostMux must be running.** The CLI queues intents into `~/.ghostmux/sync/`
and the app applies them on a 2s poll; nothing happens if the app is closed.

## Commands

```
ghostmux new [--cwd DIR] [--name NAME] [--group GROUP] [--cmd CMD] [--wait] [--unique]
ghostmux rename TARGET NEW-NAME
ghostmux group NAME
ghostmux move TARGET GROUP
ghostmux focus TARGET
ghostmux close TARGET
ghostmux ls [--json]
ghostmux sim URL [DEVICE]
```

`TARGET` is a zmx surface name (globally unique — prefer it) or a session's row
name when exactly one session carries it. `ghostmux ls` prints both.

## Rules that matter

- **Writes are async.** The command returns once the intent is queued, not once
  it's applied. Use `new --wait --name X` when the next step depends on the
  session existing; it polls `~/.ghostmux/manifest.json` and exits non-zero on
  timeout.
- **`--group` creates the group if it's missing.** Don't order a `group` call
  first. (`move` does *not* — the group must already exist there.)
- **`--cmd` takes any shell string**, run in a login shell. The pane drops to an
  interactive shell when the command finishes, so its output stays readable.
  Quote it as one argument.
- **Read state with `ls`, never by guessing.** `ls --json` gives groups →
  sessions → surfaces including live `agentKind` and `agentStatus`
  (`working` / `awaitingReply` / `blocked`) — that's how you tell whether an
  agent you launched is still going or is stuck waiting on a human.
- **Don't `close` a session you didn't create** without asking. It kills live
  work.

## Showing the user a page on iPhone

`ghostmux sim URL [DEVICE]` opens URL in Safari on an iOS Simulator — use it
when the user wants to see a page on mobile. Reuses an already-booted simulator;
otherwise boots DEVICE (name or UDID from `xcrun simctl list devices available`)
or the first available iPhone. Runs immediately (no app poll), and works even if
GhostMux is closed. A bare host gets `https://`.

## Polling loops (e.g. "watch my PRs, open a session per PR")

Inside a `/loop`, call `new --unique` every pass. It skips (exit 0) when a session
with that name already exists, so the same session isn't opened again on each pass. Use a
stable name derived from the item, never a timestamp:

```bash
gh pr list --search 'review-requested:@me' --json number,title \
  --jq '.[] | "\(.number)\t\(.title)"' |
while IFS=$'\t' read -r n title; do
  ghostmux new --unique --name "PR #$n" --group "PR Review" --cwd ~/dev/repo \
    --cmd "claude 'Review PR #$n with gh pr diff $n; summarize risks.'"
done
```

The dedup reads the manifest, which lags queued intents by ~2s, so don't fire
two passes back to back.

## Worktree fan-out

The CLI doesn't create worktrees — run `git worktree add` yourself, then point a
session at the result:

```bash
cd ~/dev/ghostmux
for i in 1 2 3 4 5; do
  git worktree add ../gm-feat-$i -b feat-$i
  ghostmux new --cwd ../gm-feat-$i --name feat-$i --group Worktrees \
               --cmd "claude 'implement feature $i'"
done
ghostmux ls
```

Sessions created this way don't carry a repo back-pointer, so GhostMux's in-app
"Remove Worktree" menu item won't appear on them — clean up with
`git worktree remove` and `ghostmux close`.

## Agent choice

`--cmd` is generic; nothing about it is Claude-specific. `claude 'prompt'`
lands in an interactive session seeded with the prompt, `claude -p 'prompt'`
runs headless and prints. GhostMux also detects `codex`, `cursor`, `pi`, and
`opencode` and reports them in `ls`.
