# User preferences (work)

## Working style — reach for subagents when asks stack up

- **When unaddressed asks queue faster than they complete** — roughly 3+ outstanding, or new ones arriving mid-task — stop, review the queue, and dispatch subagents instead of grinding through serially. Genuinely trivial edits stay inline.
- **Check file overlap before parallelising.** Group asks by the files they touch: disjoint sets run in parallel (one message, multiple tool calls), overlapping sets run sequentially. Say which you chose and why.
- **Give each subagent the full brief** — it starts with no context: worktree path, where the code lives, test framework and location, comment conventions, no ticket numbers in comments, the exact verify commands, and an explicit "do not commit, do not disturb other uncommitted work".
- **Require evidence.** Each subagent runs the type-check and tests and pastes real output. Relay what matters — I never see their report.

## Production (AWS) — hard rule

- **NEVER touch production.** No writes, mutations, deploys, deletes, or reindexing against any prod resource, ever.
- **Ask before even *reading* prod** (CloudWatch, ES, DB, S3). `prd-account-administrator-role` and prod profiles need explicit per-instance approval. Investigate in stg/tst/dev by default.

## Git workflow

- Branch prefix `jordan/` (e.g. `jordan/NES-1234-description`).
- PR titles use conventional commit format with the ticket in parentheses: `feat(NES-1234): description`, `fix(…)`, `docs(…)`, `chore(…)`.
- **Feature work happens in worktrees off the latest `release/*`, never `main`.** Keep the main working copy on the current active `release/X.Y.Z`.
- **Open a draft PR first** (`gh pr create --draft`), before doing the work, so CI runs against it from the start. Mark ready for review once the work is done and CI is green.
- Auto-merging on the Nest repo uses `--merge`; the repo rejects squash merges.
- **A failing pre-commit hook means fix the underlying issue.** Never `--no-verify`.
- **Keep the open PR and Linear ticket in sync as scope grows.** When new commits or findings land on a branch with an open PR, ask whether to update the PR title/body and the Linear ticket.

### Reporting on a PR

Always four things — clickable PR link, title, clickable Linear link, base branch. Never a bare `#4291`; that hides what it is and which train it ships on.

| PR                                                       | Title                                                      | Ticket                                                      | Targets          |
| -------------------------------------------------------- | ---------------------------------------------------------- | ----------------------------------------------------------- | ---------------- |
| [#4291](https://github.com/Nest-Genomics/nest/pull/4291) | chore(NES-5796): drain knip unlisted + unused dependencies | [NES-5796](https://linear.app/nest-genomics/issue/NES-5796) | `release/2.40.0` |

- PR link: `https://github.com/Nest-Genomics/nest/pull/<number>`
- Linear link: `https://linear.app/nest-genomics/issue/NES-<id>`, id taken from the title's conventional-commit scope.
- Scope with no real ticket (`ci`, `deps`, `portal`, `NES-QA`): write `—` rather than guessing a link.

Applies everywhere PRs are listed — status tables, triage summaries, progress updates, questions, final reports. Truncate a long title if the table needs it; keep both links and the base.

### Stacked PRs

**One PR is the default. Propose a stack, never start one unprompted.**

While researching a ticket, judge whether the work has more than one reviewable layer (schema → API → UI, refactor → feature). If it does, the proposed stack is *part of the plan*: name the layers, their order, and the branch per layer, then ask. Raise it mid-flight too — if a branch grows to contain a self-contained refactor, migration, or shared util a teammate could review alone, say so and ask. Never silently convert an in-flight branch into a stack.

Once approved: use the `gh-stack` skill for mechanics. Still a draft PR per layer up front, `jordan/` prefix and `type(NES-1234): …` titles on every layer, created inside the worktree off the latest `release/X.Y.Z`. Merge bottom-up — merging a layer lands every unmerged layer below it.

## Linear

- Default assignee Jordan (`f1ba83f4-dd6c-40f9-9d87-e6a77e52b91b`).
- **Set new tickets to `Backlog` as part of creation.** A genuinely critical ticket may stay in `Triage`, but say so and confirm rather than leaving it there silently.

## Nest local dev

- **Worktrees, `wt create`, husky hooks, lint/test concurrency** → read `~/.claude/docs/nest-worktrees.md` before running `wt`.
- **Serving `client-api`** → read `~/.claude/docs/nest-client-api.md` before `serve:client-api`; it covers the seed and index check to run automatically.
