---
name: sequester-review
description: Context-free, repeatable review of open PRs where you are a requested reviewer. Always runs in a fresh context — even when triggered mid-conversation — via a thin dispatcher that spawns an isolated orchestrator, which spawns isolated parallel reviewers. Derives all state from GitHub, finds what is new since your last review, re-verifies every claim against the code, posts exactly one consolidated comment ending in a verdict, and never submits a formal approval. Use for a scheduled/cron review loop, or on demand with "review my PR queue" / "review PR <N> with fresh eyes".
---

# Scheduled PR review

Poll a GitHub repository for PR review work and act on it. You review as the authenticated
`gh` user. **Never submit a GitHub approval.** Post review comments only, and state your
sign-off verdict in prose inside the comment. The formal approval click stays with the human —
your job is to do the work and say plainly whether it is ready.

Everything needed is in this file; all state is derived from GitHub. **No layer of this skill
ever reads a prior conversation, transcript, memory directory, or scratchpad.**

---

## Invocation contract — three layers, each a fresh context

The review must be free of whatever conversation triggered it. A conversation that has been
discussing the diff, the ticket, or the author has opinions; those opinions must not reach
the reviewers. So the skill is structured as three layers, and **each layer boundary is a
fresh context**: a newly spawned agent or a new OS process — never a continued conversation,
never a message to an existing agent.

```
Layer 0  Dispatcher    — whoever triggers the run (a person's session, or a scheduler).
                          Resolves parameters. Spawns Layer 1. Relays the report. Nothing else.
Layer 1  Orchestrator  — fresh context. Reads this file itself. Runs steps 0–6.
                          Spawns Layer 2 in one parallel batch, consolidates, verifies, posts.
Layer 2  Reviewers     — fresh contexts, parallel, blind to each other and to Layer 0.
```

### Layer 0 — the dispatcher

If you are reading this file inside a conversation, **you are Layer 0. Do not execute the
steps below yourself.** Your entire job:

1. Resolve parameters — using `gh`/`git` only, never from conversation contents:
   - `REPO` — `gh repo view --json nameWithOwner --jq .nameWithOwner`, or as given.
   - `REVIEWER` — `gh api user --jq .login`.
   - `TARGET` — `all` (poll everything in scope, the scheduled behaviour) or explicit PR
     numbers (on-demand). Explicit numbers bypass step 1; step 2 still applies unless
     `FORCE=1`.
   - `SKILL_DIR` — the directory containing this file.
2. Spawn Layer 1 as a **new** agent/process with the dispatch template below, **verbatim,
   with only the parameter slots filled**.
3. Relay Layer 1's final report to the user unchanged.

**What must not cross the boundary:** a summary of the conversation; your own reading of the
diff; the user's stated concerns ("they're worried about the retry logic"); pointers to
scratch files or memory. If the user has a specific concern, it is investigated *after* the
unbiased report comes back, as a separate follow-up — not smuggled into the brief. Never use a
"continue this agent" primitive; every dispatch is a fresh spawn.

### The dispatch template

This is the only text that crosses from Layer 0 to Layer 1.

```
Read <SKILL_DIR>/SKILL.md and execute it as the orchestrator (Layer 1).

Parameters:
  REPO=<owner/name>
  REVIEWER=<login>
  TARGET=<all | space-separated PR numbers>
  FORCE=<0|1>
  SKILL_DIR=<path>

Do not read any other conversation, transcript, memory directory, or scratchpad.
Everything you need is in that file and on GitHub.
Return the step-6 run report as your final message.
```

### Layer 1 — the orchestrator

If your prompt is the dispatch template above, you are Layer 1. Run steps 0–6. When step 3
tells you to run reviewers, spawn each as a fresh Layer 2 agent/process; do not review
inline and do not let reviewers see each other's output. You are also the consolidator and
the verifier (step 4) — the only layer that sees more than one reviewer's output.

### Layer 2 — the reviewers

Each receives only: the worktree path, the head SHA, the merge-base, the prior findings
verbatim, the evidence bar, the Project profile, and its role prompt. Nothing about the
other reviewers, nothing from Layer 0.

### The fresh-context primitive per harness

| Harness | New context | Not a new context |
|---|---|---|
| Claude Code | `Agent` tool, a new call each time. Layer 1 needs an agent type that can itself call `Agent` (e.g. `general-purpose`), not a read-only type. | `SendMessage` to an existing agent; the Skill tool inline |
| Cursor | a new `cursor-agent -p` process | `--continue` / resuming a session |
| Codex | a new `codex exec` process | resuming a session |
| Scheduler | the scheduled run *is* Layer 1; the scheduler is Layer 0 | — |

---

## 0. Resolve configuration

```bash
REVIEWER=${REVIEWER:-$(gh api user --jq .login)}
REPO=${REPO:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}
```

Neither value is ever hard-coded below.

**Project profile.** Domain weighting and repo conventions live in `## Project profile` at
the end of this file. Read it once now; it is included verbatim in every reviewer brief. If you
are adopting this skill for a different repository, that section is the only part you edit.

## 1. Find in-scope PRs

(Skipped when `TARGET` is an explicit list.)

Open, non-draft PRs where `$REVIEWER` is a **direct** reviewer (not via a team):

```bash
gh pr list --repo "$REPO" --state open --limit 300 \
  --json number,title,isDraft,headRefOid,reviewRequests \
| jq -r --arg me "$REVIEWER" '.[] | select(.isDraft==false)
    | select([.reviewRequests[]?.login] | index($me))
    | "\(.number)\t\(.headRefOid[0:10])\t\(.title)"'
```

**Do NOT use `gh search prs --review-requested=@me`** — it over-matches via team membership
AND is search-index-backed; it has silently omitted live PRs. A false *absence* is the
dangerous failure, because it reads as "nothing new".

**Submitting a review CLEARS the review request**, so PRs you already reviewed drop out of
that list. Also enumerate PRs you have previously reviewed that are still open:

```bash
gh search prs --repo "$REPO" --state open --reviewed-by "$REVIEWER" --limit 50 --json number
```

Union the two lists. Never suppress stderr — an API error means *unknown*, never *empty*.
Don't request `statusCheckRollup` in a list-wide query (it's heavy and can fail the whole
call); fetch it per-PR.

## 2. Decide what is actually new — from GitHub, not memory

For each candidate, compare the current head against the commit your last review was posted at:

```bash
gh api "repos/$REPO/pulls/<N>/reviews" \
  --jq --arg me "$REVIEWER" '[.[]|select(.user.login==$me)]|last|"\(.state) \(.commit_id)"'
```

- No prior review → **new PR, full review**.
- `commit_id` != current head → **delta review**.
- `commit_id` == current head → **skip. Do not re-review an unchanged head** (unless `FORCE=1`).

Also check `gh api "repos/$REPO/issues/<N>/comments"` for your own past comments — earlier
rounds may have been posted as plain issue comments, which do **not** carry a `commit_id` and
do **not** clear the review request. Those comment bodies are the authoritative record of what
you previously found; read the most recent one and demand a verdict on each blocker it names.

If nothing is new: report "no change" and stop. That is a successful run.

## 3. Review — spawn independent reviewers in parallel, then consolidate

Skip any PR that is draft or has failing CI (`statusCheckRollup`) — note it in the run report
and move on. **Post nothing to GitHub for these.** A "cannot assess" comment is noise on a PR
you did not actually review; the author already knows CI is red. Accept the consequence: with
no review submitted there is no `commit_id` stamp, so these PRs stay in the step-1 list and
reappear every run. That is correct — carry them as a one-line "still red, not reviewed" in the
report until CI goes green and there is something real to review.

Give each PR its own detached worktree checked out at the PR head, and **each reviewer its own
scratch subdirectory** (`<scratch>/pr<N>-<role>/`). Every reviewer operates on *the current
branch*, so they must run with that worktree as the working directory, and the base branch
must be fetched so a diff resolves:

```bash
git fetch origin "refs/pull/<N>/head:refs/remotes/pr/<N>" --force
git fetch origin <base-branch>
git worktree add --detach <worktree> <head-sha>
```

### The reviewer set

Spawn **three reviewers, in parallel, blind to each other** — one batch, not sequentially.
Each is a *role*; how a role is spawned depends on the harness — see `## Harness bindings`.

1. **General correctness reviewer** — a fresh agent running
   `<SKILL_DIR>/references/code-review.md` at level `high`. That file is a self-contained
   review prompt (fan-out by lens, then an adversarial verification pass, then a confidence
   threshold) and depends on nothing harness-specific. Read-only: it must not post comments
   and must not modify the working tree.

2. **Domain-specialist reviewer** — a fresh agent briefed with the `## Project profile` and
   matched to the surface the diff touches (backend / frontend / infra-and-tooling). This is
   the reviewer that knows the repo's rules and the product's risk model.

3. **Second-opinion reviewer on a different model family** than the other two. Use
   **fresh mode**: do not hand it your own findings, so its pass is genuinely independent and
   agreement between reviewers means something. Give it a ticket reference or an inline
   ticket summary taken from the PR title/body.

**Cap the wait and disclose.** Claude-family reviewers finish in ~4–13 minutes; a GPT pass in
~20–25. If a reviewer's output file mtime has not moved in ~45 s while the harness still says
"running", it has stalled, not slowed — kill it, do **not** re-dispatch (re-dispatching has
never recovered a stalled slot), and say in the posted comment that this was a two-reviewer
round. A zero-byte result is a failure, not a clean bill of health — that has happened.

**Sanity-check every returned review names the PR you asked about** before consolidating.
Concurrent agents sharing a scratch directory have returned a legitimate-looking review of
the wrong PR.

### Brief every reviewer the same way

Give each: the worktree path, the head SHA, the true merge-base, the prior findings verbatim,
and this evidence bar — *cite only file:line you actually read; every claim will be
independently re-verified; prefer "I could not verify X" over asserting it.* For a delta
review, require an explicit **CLOSED / PARTIAL / NOT CLOSED / REGRESSED** verdict per prior
finding with file:line evidence at the new head.

Include the domain weighting and repo rules from `## Project profile` verbatim in the brief.

**Test strength is a first-class finding.** For each test claiming to pin a fix, state the
exact production mutation that should make it fail, and whether it actually would. A test that
passes because a mock is unstubbed, or asserts only that a mock was called, is not a guard.

### Consolidate

Merge the three into one review. Where they agree, say so once — convergence from
independent reviewers is worth more than three restatements. Where they disagree, go to the
code and settle it yourself; say which reviewer was right and why. Deduplicate ruthlessly: the
same defect found three times is one finding.

Each reviewer has a characteristic bias worth correcting for. The second-opinion pass tends to
propose confident fixes that are wrong even when the finding is right — check the remedy, not
just the diagnosis. Specialist agents tend to over-report pre-existing issues as though the PR
introduced them — check the merge-base before calling anything a regression.

**Do not tear down a worktree until every reviewer on it has reported.** Scans over a deleted
tree return `count: 0`, which reads as "clean" rather than as an error. Confirm zero running
agents for that PR first. If a teardown already happened, recreate at the same SHA
(`git worktree add --detach <path> <sha>`), and treat every negative result from the interim
as unverified.

## 4. Verify before you repeat anything

Re-check every concrete claim against the code yourself. Drop what doesn't hold and say so in
a Verification notes section. Triage adversarially: decline restated design decisions,
hypotheticals and style nits **with written rationale** rather than passing them through.
When a reviewer proposes a fix, check the fix is right — a correct finding with a wrong remedy
has happened more than once.

**Where the code is pure, execute the mutation rather than reasoning about it.** Transcribing
a function into a runtime and running it against real inputs has produced the sharpest
findings of this routine. Distinguish "I executed this" from "I inferred this" in what you post.

Review worktrees have **no installed dependencies** — no suite, type-check, lint or build.
Say so explicitly and treat CI as the authority. You *can* still run pure modules: symlink a
full checkout's `node_modules` into the worktree (ESM ignores `NODE_PATH`; the symlink is what
makes resolution work) and drive the worktree's own source with `tsx`. Anything that imports
generated code will not resolve — report the mechanism as proven and the production
frequency as unmeasured rather than quoting a number you can't stand behind. Execute your
*proposed fix* the same way; a guard that false-positives on real inputs is a wrong remedy.
Remove the symlink before tearing the worktree down.

## 5. Post exactly one consolidated comment — never a GitHub approval

```bash
gh pr review <N> --repo "$REPO" --comment --body-file <file>
```

**Always `--comment`. Never pass `--approve` or `--request-changes`.** The formal approval is
the human's to give; you provide the analysis and a clear recommendation.

Use `gh pr review --comment`, **not `gh pr comment`** — the former submits a review, which
clears the review request and is stamped with a `commit_id` that step 2 depends on. A plain
issue comment does neither, so the PR reappears every run and you lose the record of which
head you reviewed.

End every comment with an explicit verdict line, so a human can act on it without re-reading
the analysis:

- **`Verdict: ready to merge as far as I can tell — no blocking findings.`** when no Critical
  and no Important finding survives *your own* verification. Say plainly that you are not
  registering a formal approval and the sign-off is theirs.
- **`Verdict: not ready — see [N] above.`** naming the specific blockers.
- For a draft or red CI: **do not post anything at all.** No review, no comment, no "cannot
  assess" verdict. Report it in the run output only.

**Calibrate to the round.** Round 1 gets full rigor. From round 2 — and hard from round 3 —
treat only absolute must-haves as blocking; the goal is to get long-running PRs finished, not
to keep finding things. A finding that is pre-existing, or that the PR strictly improves without
introducing, is not a blocker: say so and let the verdict be clean.

Be willing to be wrong. If the author answers a finding with measured evidence, withdraw it
plainly and say your premise was wrong.

## 6. Report

Per run, briefly: PRs checked, what was new, findings that survived your verification, what
you posted, which reviewers ran (and any that stalled), and which PRs you called ready
(flagging that they still need the human's approval click). Keep it to a few lines when
nothing changed. This report is your final message; Layer 0 relays it unchanged.

## Traps that have cost real time — do not relearn them

- **zsh** eats unquoted `--include=*.ts` globs, and `$SHA:path` is parsed as a zsh modifier —
  use `"${SHA}:path"`.
- **A rebased branch** makes `compare/<old>...<new>` list the entire base branch. Diff against
  `git merge-base origin/<base> HEAD` to see only the PR's own changes.
- **Do not read `reviewDecision` as your own signal.** You never approve, so it will not
  reflect your verdict. Confirm your review landed via `gh api .../pulls/<N>/reviews` and look
  for your own most recent entry and its `commit_id`.
- **Harness "running" status lies.** A reviewer that has stalled reports `running` for as
  long as you let it. The only cheap truth is the mtime of its output file. Reading its
  transcript to find out overflows your own context — don't.
- **Monorepo affected-detection may not follow path aliases** (Turbo does not follow tsconfig
  `paths`), so green CI is not evidence that a library change was type-checked against its
  consumers. Check the actual check-run list for the head.
- **Scratchpad files do not survive a restart.** Never rely on them across runs; GitHub is
  the state.
- **Large prompts in argv get the process killed** (SIGKILL 137). When driving a CLI agent,
  write the brief to a file in the reviewer's own scratch directory and tell the agent to read it.

---

## Harness bindings

The three roles in step 3 map onto whatever your harness provides. The rules above do not
change; only the spawn does. Every cell below is a *fresh* context.

| Role | Claude Code (Layer 1 uses `Agent`) | Cursor / Codex / other (Layer 1 spawns a process) |
|---|---|---|
| 1. General correctness | `general-purpose` agent, prompt = brief + "read and follow `references/code-review.md` at level high" | `cursor-agent -p` / `codex exec` with the same brief file |
| 2. Domain specialist | the reviewer agent named in Project profile routing, briefed with the profile | a process with brief + profile prepended |
| 3. Second opinion | drive a non-Claude CLI (e.g. `cursor-agent --model <gpt> --force -p`) | drive a *different* model family's CLI (e.g. `claude -p`) |

**Claude Code note on role 1.** The built-in `/code-review` skill is *not* used here on
purpose: invoked from inside a subagent it has stalled at the Skill call on every observed
attempt, and Layer 1 is always a subagent. `references/code-review.md` is the portable
equivalent and is what role 1 runs.

Driving `cursor-agent` directly — two flags that cost real time to get right:

```bash
cursor-agent --model <model> --force -p "Read <scratch>/pr<N>-gpt/REVIEW_BRIEF.md and follow it."
```

- the model flag is `--model`, **not** `-m`
- pass the brief as a file path, never as argv (see Traps)

### Scheduling

The scheduled run is Layer 1 directly; the scheduler is Layer 0 and passes the dispatch
template with `TARGET=all`.

- **Claude Code** — put this directory at `~/.claude/scheduled-tasks/<name>/` (or create it
  with `/schedule`); the task runner reads `SKILL.md` on the cron.
- **Anything else** — system cron / launchd / a CI schedule invoking the harness headless with
  the dispatch template as the prompt, e.g. `claude -p "<template>"`, `cursor-agent -p`, or
  `codex exec`. Add a few minutes of jitter so parallel users don't stampede the GitHub API on
  the hour.

Whichever way it runs, the invoking environment needs an authenticated `gh` (`gh auth status`)
and a clone of the repo — or `REPO` set explicitly.

---

## Project profile

The only section to edit when adopting this skill for another repository. Everything in it is
included verbatim in every reviewer brief.

### Domain weighting

Healthcare/PHI product. Prioritise anything that silently drops, mis-slots or
cross-contaminates clinical data; Prisma `connect`/`findUnique` on a global `@id` from client
input without `accountId` scoping; PHI in logs or LLM prompts; SQL built from untrusted input;
multi-tenancy boundaries.

### Repo rules

- No `any` without an eslint-disable + reason.
- No ticket numbers (`NES-####`) in inline comments.
- Workspace path aliases, not relative cross-package imports.
- Never write resolver spec files.
- Integration tests must call a seed fixture and assert business outcomes, and must never
  `vi.spyOn` a Prisma delegate.

### Reviewer routing (role 2)

| Diff touches | Specialist |
|---|---|
| `apps/backend/client-api` | `backend-reviewer` |
| `apps/frontend/provider-portal`, `patient-navigator`, `yoda` | `frontend-reviewer` |
| infra, CI, tooling | `general-purpose` |

### Base-branch rule

Work rides `release/X.Y.Z` or `stg`, never `main`. The merge-base for a PR is its declared
base branch; fetch that, not `main`.
