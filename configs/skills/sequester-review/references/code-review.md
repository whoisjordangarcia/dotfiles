# Code Review

Review a code change for correctness bugs and for reuse / simplification / efficiency
cleanups. Report only findings that survive verification.

## Inputs

- `TARGET` — one of: uncommitted working-tree diff (default), a branch, a PR number, or a path.
- `LEVEL` — `low` | `medium` | `high` | `max`. Default `medium`.

## Step 1 — Resolve the diff

Determine the base to diff against, in this order:
1. An explicitly supplied base.
2. For a PR: the PR's own base branch.
3. For a branch: the merge-base with the repo's integration branch.
4. Otherwise: the working tree vs `HEAD`.

Produce the unified diff plus the list of changed files. If the diff is empty, stop and say so.

Read any contributor guidance that applies to the touched paths (`CLAUDE.md`, `AGENTS.md`,
`CONTRIBUTING.md`, path-scoped rule files). Collect their paths now; read them lazily.

## Step 2 — Fan out

Dispatch independent reviewers over the diff. Scale the count to LEVEL:
`low` = 2, `medium` = 3, `high` = 5, `max` = 7.

Assign each a distinct lens; do not let two agents share one:

- **Correctness** — logic errors, off-by-one, null/undefined, unhandled rejections,
  wrong operator, inverted condition, incorrect early return.
- **Contracts** — callers and callees of every changed signature. Did a behavioral
  contract change without every call site being updated?
- **State & concurrency** — races, ordering assumptions, non-atomic read-modify-write,
  cache/DB coherence, transaction boundaries not passed through.
- **Boundaries** — untrusted input, authz checks, injection, secrets in logs, PII in
  telemetry, error messages that leak internals.
- **History** — `git log`/`git blame` on the modified regions. Was this code written
  the way it was for a reason the change now discards? Look for reverts of past fixes.
- **Guidance adherence** — the contributor-guidance files from Step 1. Only flag a
  violation you can quote a specific line for.
- **Quality** — duplicated logic that an existing helper already covers, needless
  indirection, an O(n²) loop over a collection that is unbounded in production.

Each reviewer returns candidate findings as: file, line, one-sentence defect statement,
and a concrete failure scenario (inputs/state → wrong output or crash).

**Instruct every reviewer explicitly:**
- Judge the change as written; do not propose a rewrite you would have preferred.
- A pre-existing issue is out of scope *unless* the change makes it newly reachable.
- Style, naming, and formatting are out of scope unless a guidance file mandates them.
- No finding without a failure scenario. "This could be fragile" is not a finding.

## Step 3 — Verify

This step is what separates a useful review from noise. Do not skip it.

For each candidate finding, run a *fresh* agent that has not seen the reviewer's reasoning.
Give it the diff, the finding, and the guidance file paths. It must independently attempt to
**disprove** the finding by reading the surrounding code, then score confidence 0–100:

- **0** — False positive. Does not survive light scrutiny, or is pre-existing and unchanged
  in reachability.
- **25** — Might be real; could not verify. Stylistic, and not mandated by any guidance file.
- **50** — Verified real, but a nitpick or rare in practice.
- **75** — Verified, very likely hit in practice, materially affects behavior — or is
  explicitly named in a guidance file.
- **100** — Confirmed by direct evidence; will occur frequently.

Assign `verdict: CONFIRMED` at ≥80, `PLAUSIBLE` at 50–79.

Filter by LEVEL:
- `low` / `medium` — keep ≥80 only. Few findings, high confidence.
- `high` / `max` — keep ≥50. Broader coverage; may include uncertain findings.

Deduplicate: the same root cause reported by two lenses is one finding.

## Step 4 — Report

Rank most-severe first. Emit JSON:

```json
{
  "level": "medium",
  "findings": [
    {
      "file": "src/queue/worker.ts",
      "line": 84,
      "category": "correctness",
      "short_summary": "Retry loop drops the final attempt's error",
      "summary": "One sentence stating the defect.",
      "failure_scenario": "Concrete inputs/state → the wrong output or crash.",
      "verdict": "CONFIRMED"
    }
  ]
}
```

`category` is a short kebab-case slug: `correctness`, `contracts`, `concurrency`,
`security`, `simplification`, `efficiency`, `test-coverage`, `guidance`.
`short_summary` is ≤60 chars — the claim alone, no rationale, no consequence clause.

If nothing survives verification, return `"findings": []` and say the change looks clean.
Do not pad the list to appear thorough. An empty review is a valid review.
