---
name: disk-cleanup
description: Use when the disk or data volume is nearly full, a build or download fails with ENOSPC or "No space left on device", free space keeps shrinking, or the user asks where space can be reclaimed, what can be cleaned up, or wants a live view of cleanup progress.
---

# disk-cleanup

`disk-survey` (next to this file) is a **read-only** scan of developer disk space. It ranks regenerable build
output, developer caches and agent scratchpads, says what would stop you deleting each one, and prints the reclaim
command **without running it**. You never delete anything yourself until the user has said yes to that target.

## Use it

```bash
~/.claude/skills/disk-cleanup/disk-survey            # ranked table (~/dev + ~), a few seconds
~/.claude/skills/disk-cleanup/disk-survey --live     # redraws every 3 s: free space, size per target, what was reclaimed
~/.claude/skills/disk-cleanup/disk-survey --json     # machine-readable; --root DIR, --min-kb N, --top N
```

The user may want `--live` in a split pane while they clean (see the `rex` / `ghostmux` skills), so they watch
space come back. Run it in a pane, not in your own tool call (it never exits without `--count`).

## Procedure

1. Run the survey. Report **SAFE** and **CAUTION** totals separately, biggest first, with each `blocked:` reason.
2. Add what the tool cannot judge, from `du` and the owning tool, as *manual review*: Downloads, Homebrew
   formulae and casks (`brew uses --installed <f>` first), `~/.nvm` versions, `~/.rustup` toolchains, iOS
   simulator devices (`xcrun simctl list devices`; erase one UDID, never `erase all`) and runtimes, Docker.
3. Ask which targets to reclaim. One target at a time, then re-run (or watch `--live`) to confirm the space came back.

## Before you delete anything the tool called SAFE

| Check | Why |
|---|---|
| Nothing symlinks into it (the survey reports `symlink ... points into it`) | A sibling repo's `vendor` link into an old checkout broke exactly this way. Gitignored does not mean unreferenced. |
| No process works inside it **or runs from it** (the survey reports both; `lsof +d <dir>`, `ps -p <pid>`) | A running cargo, swift or agent session fails mid-build. An MCP server started with `uvx` runs from `~/.cache/uv`: deleting the cache pulls its Python out from under it, and `uv cache prune` just waits on the lock. |
| `git worktree list` | Several checkouts can share one repo. Delete artifacts, never worktree directories. |
| Never `git clean -fdx` | It also wipes ignored `vendor/`, `.env` and local config. Remove the named directory instead. |

Everything else is on the user. A CAUTION target needs its blocker resolved or the user's explicit go-ahead.
`zig-pkg` and package caches need network to come back. Another session's scratchpad may still be in use. Never
use `sudo` without asking.

## Limits

Only known artifact kinds are scanned (cargo `target`, SwiftPM `.build`, `node_modules`, zig caches, Python
venvs, Xcode `build*`, user caches). Unknown large directories are not listed: look at `du -sh ~/dev/*` for those.
Test: `bash disk_survey_test.sh` (22+ checks on a fixture tree; it never touches the real disk).
