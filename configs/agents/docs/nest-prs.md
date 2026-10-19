# Nest PRs — opening, approving, reporting, stacking

## Opening and approving

- **Run `nest-sequester-review` locally, then open the PR.** Every push to an open PR — drafts included — burns GitHub Actions runners, so review and fix on the branch first: run it from the branch's checkout with the default `TARGET=branch`, so the report stays local. Open the PR once a pass leaves no Critical or Important findings. A draft PR (`gh pr create --draft`) is allowed earlier only when CI is genuinely needed mid-work; never mark one ready until a pass is clean and CI is green. Paste the verdict in the report.
- **`agent-approved` (green, `0E8A16`) = the sequester review passed.** Add it (`gh pr edit <n> --add-label agent-approved`) once a pass leaves no Critical or Important findings and every fix is pushed — never on a branch with pending local commits, never by hand. A later pass that finds new Critical or Important issues removes it. The label exists on Nest-Genomics/nest; create it with the same colour on other repos.
- **Cap of 4 open PRs at a time.** Before opening one, count mine with `gh pr list --author @me --state open`. At 4, do **not** open a fifth — tell me the limit is reached, list what is already open, and ask which to merge, close, or fold into an existing branch. Drafts occupy a slot too.
- **Keep the open PR and Linear ticket in sync as scope grows.** When new commits or findings land on a branch with an open PR, ask whether to update the PR title/body and the Linear ticket.

## Reporting on a PR

Always four things — clickable PR link, title, clickable Linear link, base branch. Never a bare `#4291`; that hides what it is and which train it ships on.

| PR                                                       | Title                                                      | Ticket                                                      | Targets          |
| -------------------------------------------------------- | ---------------------------------------------------------- | ----------------------------------------------------------- | ---------------- |
| [#4291](https://github.com/Nest-Genomics/nest/pull/4291) | chore(NES-5796): drain knip unlisted + unused dependencies | [NES-5796](https://linear.app/nest-genomics/issue/NES-5796) | `release/2.40.0` |

- PR link: `https://github.com/Nest-Genomics/nest/pull/<number>`
- Linear link: `https://linear.app/nest-genomics/issue/NES-<id>`, id taken from the title's conventional-commit scope.
- Scope with no real ticket (`ci`, `deps`, `portal`, `NES-QA`): write `—` rather than guessing a link.

Applies everywhere PRs are listed — status tables, triage summaries, progress updates, questions, final reports. Truncate a long title if the table needs it; keep both links and the base.

## Stacked PRs

**One PR is the default. Propose a stack, never start one unprompted.**

While researching a ticket, judge whether the work has more than one reviewable layer (schema → API → UI, refactor → feature). If it does, the proposed stack is *part of the plan*: name the layers, their order, and the branch per layer, then ask. Raise it mid-flight too — if a branch grows to contain a self-contained refactor, migration, or shared util a teammate could review alone, say so and ask. Never silently convert an in-flight branch into a stack.

Once approved: use the `gh-stack` skill for mechanics. Each layer gets its sequester pass before its PR opens, `jordan/` prefix and `type(NES-1234): …` titles on every layer, created inside the worktree off the latest `release/X.Y.Z`. Merge bottom-up — merging a layer lands every unmerged layer below it.
