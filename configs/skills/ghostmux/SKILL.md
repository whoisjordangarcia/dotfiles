---
name: ghostmux
description: Drive the running GhostMux terminal app from the shell — create sessions, launch agents in them, rename sessions, and organize them into groups. Use whenever the user asks to open/create/spin up ghostmux sessions or tabs, put sessions in a group, rename or close a ghostmux session, list what's running in ghostmux, or fan work out across several worktrees each with its own agent. Triggers on "ghostmux", "new session", "spin up N worktrees", "launch claude in a session", "what's running in ghostmux".
---

# Driving GhostMux from the shell

GhostMux is a macOS terminal multiplexer at `~/dev/ghostmux`. The CLI is
`~/dev/ghostmux/scripts/ghostmux` — symlink it onto PATH, or call it by path.

**GhostMux must be running.** The CLI queues intents into `~/.ghostmux/sync/`
and the app applies them on a 2s poll; nothing happens if the app is closed.

## Commands

```
ghostmux new [--cwd DIR] [--name NAME] [--group GROUP] [--cmd CMD] [--wait]
ghostmux rename TARGET NEW-NAME
ghostmux group NAME
ghostmux move TARGET GROUP
ghostmux focus TARGET
ghostmux close TARGET
ghostmux ls [--json]
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
