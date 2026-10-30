# Memory (work)

Global instructions for every agent on the work machine: the rules that always apply, and pointers to the rest.
Project rules belong in that project's `AGENTS.md` — not here.

## This file

- **`~/dev/dotfiles/configs/agents/AGENTS.work.md` is the work memory; edit it there, never a copy.** `memory-sync`
  symlinks `~/.claude/CLAUDE.md` and `~/.config/opencode/AGENTS.md` to it. `~/.claude/docs/` links to
  `configs/agents/docs/` in the same repo — edit pointer targets there.

## Scope — surgical changes only

- **Fix the thing I asked about. Nothing else.** The request is the deliverable, not a starting point. Adjacent code looking improvable is not a reason to widen.
- **Build for today's caller.** No abstraction for a second caller that doesn't exist, no validation for input nobody sends, no config knob for a value that never changes, no "while I'm in here" refactor. Speculative hardening costs review surface and breakage.
- **The one exception is a real defect** — something producing wrong behaviour today, or on the next run of a known-live code path. A *hypothetical* failure is not a bug. Fix it if it's in the blast radius of what I'm already touching; otherwise name it and let me decide.
- **Root cause still beats symptom.** Surgical means narrow, not shallow. One guard in the shared function every caller routes through is surgical; the same guard copy-pasted into five callers is not. Understanding the whole flow before cutting is always in scope.
- **Unrelated findings become tickets, not diff.** Tell me what turned up and offer to file it. If I say yes, dispatch a subagent to create the Linear ticket so the write-up doesn't eat the context of the work in flight — give it the full finding: file and line, what's wrong, the evidence, how it was found. Ask before filing; file rather than fix.
- **When a fix has genuinely separable layers, name them and ask.** Default to shipping only the layer that fixes the reported problem.

## Comments — shut up and code

A comment is **load-bearing** when deleting it costs a competent reader something the code cannot tell them; write only those. "normal comments" turns it off — confirm in one line, then revert.

**Before writing any comment, and at the end of every turn that edited files, apply `~/.claude/docs/comments.md`** — the test, the load-bearing kinds, contracts, and the audit point. It does not lapse when the topic changes.

## Commits and PRs — no AI attribution

- **Never write `Co-Authored-By: Claude …`, "Generated with Claude Code", or any AI attribution** into a commit message or PR body. `attribution`/`includeCoAuthoredBy` in settings only stop the automatic one; this covers the ones typed by hand.

## Production (AWS) — hard rule

- **NEVER touch production.** No writes, mutations, deploys, deletes, or reindexing against any prod resource, ever.
- **Ask before even *reading* prod** (CloudWatch, ES, DB, S3). `prd-account-administrator-role` and prod profiles need explicit per-instance approval. Investigate in stg/tst/dev by default.
- **Use `management-account-administrator-role` only when a task cannot be done without it.** Default to the env profile (`tst-`/`stg-account-administrator-role`). When management is genuinely required (Terraform state backend, Route53), say why before asking me to log into it.

## Git workflow

- Branch prefix `jordan/` (e.g. `jordan/NES-1234-description`).
- PR titles use conventional commit format with the ticket in parentheses: `feat(NES-1234): description`, `fix(…)`, `docs(…)`, `chore(…)`.
- **Feature work happens in worktrees off the latest `release/*`, never `main`.** Keep the main working copy on the current active `release/X.Y.Z`.
- Auto-merging on the Nest repo uses `--merge`; the repo rejects squash merges.
- **A failing pre-commit hook means fix the underlying issue.** Never `--no-verify`.
- **Any PR action — opening, marking ready, labelling, listing or reporting, stacking, or new commits landing on an open PR — read `~/.claude/docs/nest-prs.md` first.** In short: run `nest-sequester-review` locally and open the PR only after a clean pass (every push to an open PR burns GitHub Actions runners); at most 4 open PRs; `sequester-approved` only from a clean pass with fixes pushed; report PRs as link + title + Linear link + base branch; propose a stack, never start one.

## Linear

- Default assignee Jordan (`f1ba83f4-dd6c-40f9-9d87-e6a77e52b91b`).
- **Set new tickets to `Backlog` as part of creation.** A genuinely critical ticket may stay in `Triage`, but say so and confirm rather than leaving it there silently.

## Pointers

Read the target when the task hits the trigger, not before.

- **Asks stacking up** (3+ outstanding, or new ones arriving mid-task) **or dispatching any subagent** → `~/.claude/docs/subagents.md`.
- **Worktrees, `wt create`, reviewing or running a PR locally (`wt review --from-ci`), husky hooks, lint/test concurrency** → `~/.claude/docs/nest-worktrees.md`, before running `wt`.
- **Serving `client-api`** → `~/.claude/docs/nest-client-api.md`, before `serve:client-api`; it covers the seed and index check to run automatically.
- **Checking an email or SMS went out, or grabbing a sign-in link** → `~/.claude/docs/nest-mailpit.md`.
- **Notes vault `~/dev/notes`** → `rg` and native file tools for text; the `obsidian` skill for daily notes and Obsidian metadata (tasks, tags, backlinks, frontmatter). Why: `~/dev/notes/10 - Meta/Vault Tooling Decision.md`.
- **MUI questions** → the `mui-mcp` server: `useMuiDocs` for the package, then `fetchDocs` on URLs it returned only; answer from what was fetched.
