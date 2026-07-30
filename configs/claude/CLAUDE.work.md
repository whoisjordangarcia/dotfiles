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
- **ALWAYS ask first before even _reading_ prod** (CloudWatch logs, ES, DB, S3, etc.). Do not query the `prd-account-administrator-role` / prod profiles without explicit per-instance approval. Default to lower environments (stg/tst/dev) for investigation.

## Git Workflow

- When creating a new branch, always use the prefix `jordan/` (e.g., `jordan/NES-1234-description`)
- PR titles must use conventional commit format with the ticket number in parentheses: `feat(NES-1234): description`, `fix(NES-1234): description`, `docs(NES-1234): description`, `chore(NES-1234): description`, etc.
- When auto-merging PRs on the Nest repo, always use `--merge` (not `--squash`). The repo does not allow squash merging.
- **NEVER use `--no-verify` to bypass pre-commit hooks.** If a hook fails, fix the underlying issue instead.
- **Always open a draft PR first.** When starting any new branch or worktree, create the PR as a draft (`gh pr create --draft`) _before_ doing the work; mark it ready for review only once the work is done and CI is green. For a worktree, the first step after the branch exists is the draft PR, so CI runs against it from the start.
- **Do feature work in worktrees branched off the latest `release/*`, never on `main`.** Keep the main working copy on the current active `release/X.Y.Z`.
- **Keep the open PR and Linear ticket in sync as scope grows.** When new commits/tasks/findings land and a PR is open, ask whether to update the PR (title/description/body) and the Linear ticket (comment or description) so neither drifts behind what's actually on the branch.

## Linear

- When creating Linear tickets, always default assignee to Jordan (ID: `f1ba83f4-dd6c-40f9-9d87-e6a77e52b91b`)
- **Move new tickets to `Backlog`, never leave them in `Triage`.** Set the status to `Backlog` as part of creation. Exception: if a ticket is genuinely critical and needs to be raised with the team first, it may stay in `Triage` — but say so and confirm with the user rather than silently leaving it there.

## Nest Local Dev (worktrees, hooks, tests)

- **Run `pnpm exec husky` before your first commit in a new worktree.** `core.hooksPath` points at `.husky/_/`, which is gitignored and not created automatically in new worktrees; when it's missing, git silently skips all hooks (lint-staged, prettier, eslint) and unformatted code lands on the branch and breaks CI. It's idempotent and also runs via `pnpm i` / `nx run doctor`. Verify with `ls "$(git config --get core.hooksPath)/pre-commit"`.
- **Creating a worktree non-interactively (`wt create`): use `--headless`, never `script`.** `wt create` has an Ink-free headless path, taken on explicit `--headless` or whenever either stdin or stderr is not a TTY — so it already works under the agent `Bash` tool / CI / piped stdin:
  ```bash
  ~/.nest/bin/wt create --headless NES-1234-my-fix release/X.Y.Z --setup install
  ```
  > [!IMPORTANT]
  > **Never wrap `wt` in `script -q` to "give it a pty".** The gate is
  > `stdin.isTTY && stderr.isTTY → run the TUI`, and a pty makes *both* true —
  > so `script` defeats the headless path and forces the TUI back on. On any
  > failure the TUI then parks on `Press any key to exit` waiting for a keypress
  > that can never arrive, and the `zsh` + `script` pair survives the session as
  > immortal orphans (reparented to launchd) until killed by hand. It also hides
  > the real error behind that prompt. Adding `< /dev/null` does **not** fix it:
  > that redirects `script`'s own stdin while the child still inherits the pty
  > slave, so `isTTY` stays true. Drop `script` entirely.

  Call the binary `~/.nest/bin/wt` directly (the `wt` shell function only `cd`s your interactive shell, which doesn't persist from a tool call). Headless **requires both** `name` and a `release/X.Y.Z` base-ref (never `main`) — it exits 1 with a usage error if either is missing, rather than prompting. The created path goes to stdout, terse progress to stderr. Default setup is full and slow — background it and tail the log, or use `--setup install` for just deps + husky. Verify a run exited rather than parked: `timeout 600 … ; echo "exit=$?"` (124 = hung, which should now be impossible).
- **`wt remove` and `wt prune` have the same `--headless` flag** and the same non-TTY auto-detection — same rules apply.
- **Cap lint/test concurrency at 3** so the machine stays responsive: `turbo run lint --concurrency=3 --filter=<app>` / `turbo run test --concurrency=3 --filter=<app>`.
- **When running client-api, auto-check seed + index first.** Before (or right after) bringing up `serve:client-api` for an instance, check whether the instance DB has been seeded and the ES indexes built, and run them automatically if not — don't wait to be asked. Cheap checks against the instance's shared infra (Postgres 5432 / ES 9244): a seeded DB has rows in `nestclientapi."Patient"` (e.g. `psql … -tAc 'SELECT count(*) FROM nestclientapi."Patient"'` > 0); indexes exist when the instance's ES prefix (`dev-<instance>-patients-v1` etc.) returns docs. If either is empty, run `pnpm run seed` then `pnpm run index-all-records` with the instance env (shared-infra port overrides, same recipe as serving the API). It's a once-off per instance — seed/index persist in the shared Postgres/ES, so skip when already populated.
