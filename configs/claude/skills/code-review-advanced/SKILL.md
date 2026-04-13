---
name: code-review-advanced
description: Use when completing frontend features, before merging frontend PRs, or when asked to do a thorough review. Runs React composition, React performance, web design guidelines, and code-reviewer audits together. Triggers on "full review", "advanced review", "frontend audit", or "review everything".
---

# Advanced Code Review

Run four complementary audits on changed frontend code, then synthesize findings into a single prioritized report.

## Audits

| # | Skill | Focus |
|---|-------|-------|
| 1 | `vercel-composition-patterns` | Component architecture, boolean prop proliferation, compound components |
| 2 | `vercel-react-best-practices` | Performance — waterfalls, bundle size, re-renders, server-side patterns |
| 3 | `web-design-guidelines` | UX, accessibility, interaction design |
| 4 | `superpowers:requesting-code-review` | Code correctness, plan compliance, architecture |

## How to Run

### 1. Identify changed files

```bash
git diff --name-only <base-branch>...HEAD -- '*.tsx' '*.ts' '*.css'
```

### 2. Dispatch all four audits in parallel

Use the Agent tool to launch four subagents simultaneously in a single message. Each subagent should:
- Receive the list of changed files
- Invoke its respective skill via the Skill tool
- Return findings in `file:line — issue` format

```
Agent 1 → Skill("vercel-composition-patterns", "<changed files>")
Agent 2 → Skill("vercel-react-best-practices", "<changed files>")
Agent 3 → Skill("web-design-guidelines", "<changed files>")
Agent 4 → superpowers:code-reviewer subagent (see requesting-code-review skill for template)
```

### 3. Synthesize results

After all four agents return, combine findings into a single report:

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

## When to Use

- After completing a frontend feature
- Before creating a PR for frontend changes
- When asked to do a "full review" or "thorough review"
- Periodically during large frontend refactors

## When NOT to Use

- Backend-only changes (use `superpowers:requesting-code-review` alone)
- Single-file quick checks (use the individual skill directly)
- Non-code reviews (PRDs, docs)
