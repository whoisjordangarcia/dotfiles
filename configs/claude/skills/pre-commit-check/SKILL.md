---
name: pre-commit-check
description: "PROACTIVE: Run automatically before EVERY git commit and git push, not just when asked. Also use after a rebase, or when user says 'run checks', 'pre-commit', 'validate'. Runs lint, type check, unit tests, and story schema lint for affected Nx projects based on changed files."
---

# Pre-Commit Check

Run lint, type check, unit tests, and story schema validation for Nx projects affected by your changes. **Uses CI-equivalent commands** to catch issues before push.

## When to Use

- **AUTOMATICALLY before every `git commit` and `git push`** — do not wait for the user to ask
- After resolving merge conflicts or rebasing
- When user says "run checks", "pre-commit", "validate"
- After fixing any check failure (re-run ALL checks, not just the failing one)

## Pre-Commit Hook Status

The repo uses **Husky + lint-staged** (`lint-staged.config.js`). If hooks aren't working:
```bash
pnpm run setup-hooks   # Re-initialize husky
```
The hook runs eslint, prettier, `nx affected --target=check-types`, and story schema linting on staged files automatically. This skill runs **broader branch-level checks** including unit tests.

## Steps

1. Identify affected projects from changed files using `git diff --name-only` against the base branch
2. For each affected project, run these checks **in parallel**:

### Lint (CI mode — no auto-fix, no cache)

Use `lint:ci` target when available, otherwise fall back to `lint`:

| Project | Command |
|---------|---------|
| patient-navigator | `nx run patient-navigator:lint:ci` |
| provider-portal | `nx run provider-portal:lint` |
| client-api | `nx run client-api:lint` |

**Important:** `lint:ci` for patient-navigator runs `eslint src` (no `--fix`, no `--cache`) plus story schema freshness checks and story connection linting — matching what CI runs. The regular `lint` target uses `--fix` which hides errors that CI will catch.

### Type Check

```bash
nx run <project>:check-types
```

### Unit Tests

```bash
nx run <project>:test
```

### Story Schema Lint (patient-navigator only)

Already included in `lint:ci` for patient-navigator. For manual runs:
```bash
nx run patient-navigator:lint-stories-schema
```

## Fix-and-Recheck Loop

**IMPORTANT:** If any check fails, fix the issue and re-run ALL checks — not just the failing one. Fixes often introduce new issues (e.g. adding properties breaks `sort-keys-fix`, prettier fixes change line structure). Repeat until all checks pass.

```
Run checks → failure? → fix → re-run ALL checks → still failing? → fix → re-run ALL checks → all green → commit & push
```

**Rule:** Only commit and push after a fully clean run where lint, types, and tests ALL pass with zero changes made after the checks completed.

## Interpreting Results

- **Pre-existing failures:** Some tests or type checks may fail due to missing generated files (e.g. `__generated__/graphql`). Run `nx run doctor` to fix. Compare against base branch to distinguish pre-existing vs new failures.
- **Lint warnings as errors in CI:** CI runs eslint without `--fix` so prettier formatting issues become errors. Always use `lint:ci` to catch these locally.
