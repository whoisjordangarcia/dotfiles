<!--
  Work-environment Claude instructions (overlay).

  This file is the WORK overlay for ~/.claude/CLAUDE.md. script/claude/setup.sh
  appends it to the shared base (configs/claude/CLAUDE.md) when WORK_ENV=1 /
  DOT_ENVIRONMENT=work, producing the single ~/.claude/CLAUDE.md that Claude
  reads. Edit it here OR edit ~/.claude/CLAUDE.md live and run `claude-sync`
  (script/claude/sync-claude.sh) to write your edits back here.

  Add work-machine-only instructions below this comment.
-->

# User Preferences

## Production (AWS) — Hard Rule

- **NEVER touch production.** No writes, mutations, deploys, deletes, or reindexing against any prod resource — ever.
- **ALWAYS ask first before even *reading* prod** (CloudWatch logs, ES, DB, S3, etc.). Do not query the `prd-account-administrator-role` / prod profiles without explicit per-instance approval. Default to lower environments (stg/tst/dev) for investigation.

## Git Workflow

- When creating a new branch, always use the prefix `jordan/` (e.g., `jordan/NES-1234-description`)
- PR titles must use conventional commit format with the ticket number in parentheses: `feat(NES-1234): description`, `fix(NES-1234): description`, `docs(NES-1234): description`, `chore(NES-1234): description`, etc.
- When auto-merging PRs on the Nest repo, always use `--merge` (not `--squash`). The repo does not allow squash merging.
- **NEVER use `--no-verify` to bypass pre-commit hooks.** If a hook fails, fix the underlying issue instead.
- **Always open a draft PR first.** When starting any new branch or worktree, create the PR as a draft (`gh pr create --draft`) *before* doing the work; mark it ready for review only once the work is done and CI is green. For a worktree, the first step after the branch exists is the draft PR, so CI runs against it from the start.
- **Do feature work in worktrees branched off the latest `release/*`, never on `main`.** Keep the main working copy on the current active `release/X.Y.Z`.
- **Keep the open PR and Linear ticket in sync as scope grows.** When new commits/tasks/findings land and a PR is open, ask whether to update the PR (title/description/body) and the Linear ticket (comment or description) so neither drifts behind what's actually on the branch.

## Linear

- When creating Linear tickets, always default assignee to Jordan (ID: `f1ba83f4-dd6c-40f9-9d87-e6a77e52b91b`)
- **Move new tickets to `Backlog`, never leave them in `Triage`.** Set the status to `Backlog` as part of creation. Exception: if a ticket is genuinely critical and needs to be raised with the team first, it may stay in `Triage` — but say so and confirm with the user rather than silently leaving it there.

## Nest Local Dev (worktrees, hooks, tests)

- **Run `pnpm exec husky` before your first commit in a new worktree.** `core.hooksPath` points at `.husky/_/`, which is gitignored and not created automatically in new worktrees; when it's missing, git silently skips all hooks (lint-staged, prettier, eslint) and unformatted code lands on the branch and breaks CI. It's idempotent and also runs via `pnpm i` / `nx run doctor`. Verify with `ls "$(git config --get core.hooksPath)/pre-commit"`.
- **Creating a worktree non-interactively (`wt create`):** `wt` is an Ink TUI that needs raw mode on a TTY, so under the agent `Bash` tool / CI / piped stdin it dies with `Raw mode is not supported`. There's no `--headless` for `create`; allocate a pty with `script` and pass both args so the form is skipped:
  ```bash
  script -q /tmp/wt-create.log ~/.nest/bin/wt create NES-1234-my-fix release/X.Y.Z
  ```
  Call the binary `~/.nest/bin/wt` directly (the `wt` shell function only `cd`s your interactive shell, which doesn't persist from a tool call). Pass both `name` and a `release/X.Y.Z` base-ref (never `main`). Default setup is full and slow — background it and tail the log, or use `--setup install` for just deps + husky.
- **Cap lint/test concurrency at 3** so the machine stays responsive: `turbo run lint --concurrency=3 --filter=<app>` / `turbo run test --concurrency=3 --filter=<app>`.

## Code Style

- No magic values — always use existing utils/constants. If none exist, hoist the value to a constant at the top of the file or in the appropriate constants module.

## Ralph loop / prd

- When creating unit test from a ralph loop or is doing work from tasks/prd.md don't specify the task number: (US-002: add unit test)

## cmux Workspace Titles + State

This session usually runs inside a **cmux** workspace, kept in sync automatically by
hooks in `settings.json` (scripts in `~/.claude/scripts/`, shared identity in
`cmux_common.py` keyed off `GHOSTTY_SURFACE_ID`). **You normally do nothing** — it's
all hook-driven:

- **Title** (`cmux-title.py`) = `NES-#### · <topic>`. The topic auto-tracks: it reads
  Claude Code's live terminal/surface title on every `Stop`, strips status glyphs, and
  prefixes the detected Linear ticket (most-recent NES-#### the *user typed*). No
  worktree fallback — the description already names the worktree, so before the first
  topic the title is just the ticket (or left untouched when there's no ticket).
- **Description** = not managed by the hooks (cmux shows the workspace folder
  natively; descriptions are free for manual notes).
- **PR approval** (`cmux-pr.py`) = a sidebar status pill `✓ Approved #<n>` (via
  `cmux set-status review`) when the branch's PR has an approving review; cleared
  otherwise. *CI status is intentionally left to cmux's native PR watcher* — this
  pill only adds the approval signal the watcher doesn't show. Refreshed on
  `SessionStart`, `Stop`, and after `git push`/`gh pr create`.
- **Task progress** (`cmux-progress.py`) = a sidebar progress bar (via
  `cmux set-progress`) driven by `TodoWrite`: `completed/total` of the active todo
  list, labelled with the in-progress task. Cleared on `SessionStart`; a finished
  list sits at 100% until the next list resets it.

The scripts live in the dotfiles repo at `configs/claude/scripts/` (symlinked to
`~/.claude/scripts`). All three no-op cheaply when cmux isn't running (the shared
`cmux_common.alive()` short-circuits on socket existence — no subprocess on a
closed cmux or non-macOS box).

**Manual override wins:** if the user renames the workspace in cmux, the script detects
current != last-set and backs off permanently for the session. Never try to "correct" a
human-set title. An explicit `cmux-title.py --topic "short topic"` override exists but is
rarely needed since the topic tracks automatically.
