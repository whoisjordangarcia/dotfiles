---
name: code-review-advanced
description: Use when completing a feature, before merging a PR, or when asked to do a thorough review. Routes changed files to backend and frontend audits — repo backend conventions, React composition, React performance, web design guidelines, and code-reviewer — then synthesizes them. Triggers on "full review", "advanced review", "frontend audit", "backend audit", or "review everything".
---

# Advanced Code Review

Route the changed files to the audits that fit them, then synthesize every
finding into a single prioritized report.

## Audits

Which ones run depends on what the diff touches. Audits 1–3 are frontend-only;
audit 4 is backend-only; audit 5 always runs.

| # | Runs when | Agent / skill | Focus |
|---|---|-------|-------|
| 1 | frontend files | `vercel-composition-patterns` | Component architecture, boolean prop proliferation, compound components |
| 2 | frontend files | `vercel-react-best-practices` | Performance — waterfalls, bundle size, re-renders, server-side patterns |
| 3 | frontend files | `web-design-guidelines` | UX, accessibility, interaction design |
| 4 | **backend files** | **`backend-reviewer` agent** | **Repo backend conventions — transactional `tx` passing, queue/role gating, expand-contract migration safety, PHI-safe logging, testing hard rules** |
| 5 | always | `superpowers:code-reviewer` agent | Code correctness, plan compliance, architecture |

In a repo that ships its own reviewer agents, prefer them over the generic
skills — in the Nest monorepo that means `backend-reviewer` for `apps/backend/**`
and `libs/**`, and `frontend-reviewer` for `apps/frontend/**` alongside audits
1–3. They carry the repo's conventions; the generic skills do not.

**Every file in the diff must be covered by at least two independent audits.**
A backend file seen only by audit 4, or a frontend file seen only by audit 5, is
a single unchecked opinion — add the other reviewer rather than shipping one.

## How to Run

### 1. Identify changed files

Infer the base branch — never assume `main` (in the Nest repo it is the newest
`origin/release/*` or `origin/stg`; see that repo's CLAUDE.md).

```bash
git diff --name-only <base-branch>...HEAD
```

If that list is empty, fall back to the working tree (`git status --short`).
Nothing changed → say so and stop; don't run the audits on nothing.

Now **split the list into two sets**, because they select different audits:

```bash
# frontend → audits 1-3 (+ frontend-reviewer where the repo has one)
git diff --name-only <base-branch>...HEAD -- '*.tsx' '*.jsx' '*.css' 'apps/frontend/**'

# backend → audit 4
git diff --name-only <base-branch>...HEAD -- 'apps/backend/**' 'libs/**' '*.prisma' 'prisma/**'
```

Adjust the globs to the repo's layout; the split is the point, not these paths.
A file can land in both sets (a shared lib consumed by a UI), and that is fine —
it just earns both reviews.

Reviewing a PR rather than the working tree? Fetch its head read-only and diff
against the merge base, so a busy working tree stays untouched:

```bash
git fetch origin pull/<N>/head:refs/remotes/pr/<N> --force -q
git diff --name-only <base-branch>...pr/<N>
```

Then brief every agent to read files with `git show pr/<N>:<path>` and forbid
checkout outright. Never check the branch out — concurrent audits would
serialize on the index and can clobber uncommitted work.

### 2. Dispatch every selected audit in parallel

Launch the subagents with the Agent tool **in a single message** so they run
concurrently. Subagents start with zero context, so each prompt must be
self-contained. Use this template, substituting `<SKILL>`, `<FOCUS>`, the repo
path, and the file list — say "backend" or "frontend" to match the set:

> You are auditing `<backend|frontend>` changes in `<repo path>`.
>
> **First, invoke the `<SKILL>` skill with the Skill tool and follow it.** Do
> not review from memory — the skill body is the rubric.
>
> Files changed on this branch (read each one in full, plus whatever they
> import that you need to judge them):
> ```
> <one path per line>
> ```
>
> Focus: `<FOCUS>`.
>
> Report every finding as `path/to/file.tsx:LINE — <one-sentence issue> — <one-sentence fix>`,
> grouped under `CRITICAL` / `IMPORTANT` / `MINOR`. Quote the offending line.
> Cite nothing you have not read. If a category is clean, write `none`.
> End with a `PASSING` list of what the changes do well.
>
> Read-only: do not edit, stage, or commit anything.

| Agent | File set | Skill to invoke / agent type | Focus to pass |
|---|---|---|---|
| 1 | frontend | `vercel-composition-patterns` | Component architecture — boolean prop proliferation, compound components, render props, context boundaries, React 19 API changes |
| 2 | frontend | `vercel-react-best-practices` | Performance — data waterfalls, bundle size, needless re-renders, `use client` boundaries, server-side patterns |
| 3 | frontend | `web-design-guidelines` | UX and accessibility — focus/keyboard, contrast, labels and roles, loading/empty/error states, responsive behaviour |
| 4 | **backend** | **`backend-reviewer` agent type** | **Data layer and service correctness — transaction (`tx`) passing, queue/role gating, expand-contract migration safety, PHI-safe structured logging, no `any`, no ticket numbers in comments, and the repo's testing hard rules. Trace every caller of anything whose behaviour or signature changed, including callers the diff did not touch.** |
| 5 | all | `superpowers:code-reviewer` agent type | Correctness, plan compliance, architecture — per `superpowers:requesting-code-review`'s template |

Agents 1–3 run as `general-purpose`. Agents 4 and 5 use their own agent types,
which carry their own templates — give each the relevant file list, and give
agent 5 the original task/plan it should be checking against.

Where the repo ships a `frontend-reviewer` agent, dispatch it on the frontend set
too — it enforces per-app conventions (component wrappers, codegen usage, path
aliases, which test layer belongs where) that audits 1–3 know nothing about.

**Outbound and cross-boundary code earns extra scrutiny in the backend brief.**
When the diff builds a payload for a third party, writes to a shared table, or
changes a query other callers share, say so in the prompt: a wrong value there
is not recoverable by a redeploy, and the reviewer should weigh it accordingly.

If a subagent returns without having invoked its skill (its report reads generic,
cites no rubric), re-dispatch that one agent rather than accepting the output.

### 2a. Run every audit at `xhigh` effort

This skill is the thorough review. Cheap audits produce plausible findings
nobody can act on, so spend the tokens.

**The effort level is `xhigh`, not `max`.** Use that word exactly — `max` is a
separate, more expensive tier and is not what this skill asks for.

- **Pass `model: "opus"` on every `Agent` call.** Never let an audit inherit a
  smaller tier — the findings that justify this skill are the ones that require
  reading the other side of a boundary, and those are exactly what a cheaper
  model rounds off.
- **The `Agent` tool has no `effort` parameter.** Its inputs are `description`,
  `prompt`, `subagent_type`, `model`, `isolation` — nothing else. Depth comes
  from `model` plus the brief, so do not write `effort:` into an `Agent` call
  expecting it to take. Subagents inherit reasoning effort from the session
  (`effortLevel` in `~/.claude/settings.json`); if it is below `xhigh`, say so
  before dispatching so the user can raise it, rather than silently running the
  thorough review at the cheap tier.
- **Only `Workflow`'s `agent()` accepts `effort`.** If you orchestrate these
  audits through a workflow instead, pass `effort: 'xhigh'` on every review and
  verify stage.
- **Buy depth in the brief, since that is the lever that works.** Every audit
  prompt must say: read each changed file *in full at the reviewed commit*,
  trace every caller of anything whose behaviour changed (including callers the
  diff did not touch), and verify the author's stated claims against the code
  rather than accepting them. Add: *cite nothing you have not read.*
- **Do not cap the audit count when the diff spans layers.** Scale the fan-out to
  what changed, and hold the floor of two independent reads per file. A PR
  touching backend, shared libs and UI is not one review — it is a backend
  review, a frontend review, and a correctness review that happen to share a
  branch.

### 2b. Keep the audits independent

The value of N audits is N *uncorrelated* reads. Anything shared between them
collapses that back into one opinion counted N times.

- **Never use `subagent_type: "fork"`.** A fork inherits the parent's whole
  conversation, framing and hunches included. Every audit agent must start cold,
  knowing only the repo path, the file list, and its own skill.
- **Put no findings, theories, or suspicions in the prompt.** Not "check whether
  the modal leaks focus", not "I think the re-renders come from the provider" —
  just the files and the focus area. A named suspicion is a hypothesis the agent
  will work to confirm.
- **Dispatch them all in one message.** Sequential dispatch tempts you to feed
  agent 1's output into agent 2's prompt, which is the same anchoring by another
  route. No agent sees another's report — and the backend and frontend agents
  reviewing the same PR must not see each other's either.
- **Re-dispatch, never patch.** If one audit comes back thin, send that agent's
  brief again unchanged. Adding "you missed the accessibility issue in Foo.tsx"
  turns an independent audit into dictation.
- **The parent stays quiet until every agent lands.** Form no view of the diff
  and write no review of your own before synthesis — the synthesis step is where
  your judgement enters, not the dispatch step.
- **Give the author's own claims only to agent 5.** The PR description is the
  spec that correctness/plan-compliance is judged against, so it belongs there.
  Handing it to the backend and frontend reviewers as well seeds them with the
  author's framing and costs you the independent read you paid for.

Corollary for step 3: when two agents that never saw each other flag the same
line, that is corroboration and the finding ranks up. Independence is what earns
that inference.

### 3. Synthesize results

After every agent returns, combine findings into a single report:

```markdown
## Advanced Code Review — Summary

### Critical (fix before merge)
- [findings from any audit]

### Important (fix before next task)
- [findings]

### Minor (address later)
- [findings]

### Passing
- [what looks good across all audits]
```

Deduplicate overlapping findings. If two audits flag the same issue, keep the more specific one.

Two more things the synthesis must do:

- **Say when independent agents corroborated a finding, and rank it up.** Two
  cold reads landing on the same line is evidence; one read is an opinion.
- **Report disagreements rather than picking a winner silently.** When two
  agents rate the same issue differently, the split is usually informative —
  often one explains why the current code is wrong and the other why the obvious
  fix is worse. Merge them and say so.

## When to Use

- After completing a feature, backend or frontend
- Before creating or approving a PR
- When asked to do a "full review" or "thorough review"
- When reviewing someone else's PR that spans more than one layer
- Periodically during large refactors

## When NOT to Use

- Single-file quick checks (use the individual skill directly)
- Non-code reviews (PRDs, docs)

Backend-only diffs are **in** scope — that is what audit 4 is for. Step 1's
split will simply return an empty frontend set, audits 1–3 won't run, and the
review is `backend-reviewer` + `superpowers:code-reviewer` at the §2a bar. Do
not bounce a backend PR out of this skill.
