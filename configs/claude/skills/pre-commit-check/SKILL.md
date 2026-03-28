---
name: pre-commit-check
description: "PROACTIVE: Run automatically before EVERY git commit and git push in the Nest repository, not just when asked. Also use after a rebase, or when user says 'run checks', 'pre-commit', 'validate'. Runs lint, type check, unit tests, E2E tests (when e2e files changed), and story schema lint for affected Nx projects based on changed files. Only applies to the Nest monorepo."
---

# Pre-Commit Check

Run lint, type check, unit tests, E2E tests (when e2e files changed), and story schema validation for Nx projects affected by your changes. **Uses CI-equivalent commands** to catch issues before push.

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
The hook runs eslint, prettier, `nx affected --target=check-types`, and story schema linting on staged files automatically. This skill runs **broader branch-level checks** including unit tests and E2E tests.

## Step 1: Verify Pre-Commit Hooks

Check that husky is installed and the pre-commit hook exists:
```bash
test -f .husky/pre-commit && echo "Husky pre-commit hook exists" || echo "Missing! Run: pnpm run setup-hooks"
```
If missing, run `pnpm run setup-hooks` to enable husky.

## Step 2: Identify Changed Files and Affected Projects

Diff against the base branch to find all changed files on this feature branch:
```bash
# Find the base branch (usually release/X.X.X)
git log --oneline --decorate -20  # Look for the fork point

# Get changed files vs base
git diff --name-only <base-branch>...HEAD
git diff --name-only  # Also check uncommitted changes
```

Map changed files to Nx projects:
| Path prefix | Project | Checks |
|---|---|---|
| `apps/backend/client-api/` | `client-api` | test, check-types, lint |
| `apps/frontend/patient-navigator/` | `patient-navigator` | check-types, lint, e2e |
| `apps/frontend/provider-portal/` | `provider-portal` | check-types, lint, e2e |
| `libs/` | Affected libs | check-types |

Additional checks based on file types:
- `*/e2e-tests/*.spec.ts` or `*/e2e-tests/utils/*` changed → run `nx run <project>:e2e` for that project
- `*.story.json` changed → run `nx run patient-navigator:lint-stories-schema`
- `*.gql` or `graph.gql` changed → run `pnpm run generate-graphql-definitions` first
- `schema.prisma` changed → run `nx run client-api:migrate:dev` first
- `__generated__/` files changed → remind user to run `pnpm run generate-graphql-definitions`

## Step 3: Run Checks in Parallel

For each affected project, run checks **in parallel** using background Bash tasks:

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

For `client-api:test`, if only specific test files changed, run those: `nx run client-api:test <pattern>`

### E2E Tests

Run E2E tests for a frontend project when **any** of its files changed — not just e2e test files. Source code changes (components, hooks, utils) can break E2E tests just as easily as test file changes can.

```bash
# Run a specific e2e spec (when only specific e2e files changed)
nx run provider-portal:e2e --grep "spec name pattern"

# Run all e2e for the project (when source files changed)
nx run provider-portal:e2e
nx run patient-navigator:e2e
```

| Changed path | Command |
|---|---|
| `apps/frontend/provider-portal/**` | `nx run provider-portal:e2e` |
| `apps/frontend/patient-navigator/**` | `nx run patient-navigator:e2e` |
| `libs/**` (shared frontend libs) | Run e2e for projects that consume the lib |

When only specific e2e spec files changed (and no source files), you may scope with `--grep` to save time. Otherwise run the full e2e suite for the project.

### Story Schema Lint (patient-navigator only)

Already included in `lint:ci` for patient-navigator. For manual runs:
```bash
nx run patient-navigator:lint-stories-schema
```

Run all independent checks simultaneously. Collect results.

## Step 4: Report Results

Provide a clear summary table:

```
Pre-Commit Checks
──────────────────────────────────────
Base branch: release/X.X.X
Changed projects: client-api, provider-portal

Lint (patient-navigator)          passed
Type Check (patient-navigator)    passed
Unit Tests (client-api)           3590 passed
E2E Tests (provider-portal)       72 passed
Type Check (client-api)           FAILED (pre-existing on base branch)

──────────────────────────────────────
Result: Ready to commit (failures are pre-existing)
```

## Step 5: Distinguish Pre-Existing vs New Failures

If a check fails, determine whether the failure is **pre-existing on the base branch** or **introduced by this branch**:
- Check if the failing files were modified by this branch
- If errors are in files NOT touched by this branch, flag as "pre-existing"
- Only block commit for failures **introduced by this branch**

## Fix-and-Recheck Loop

**IMPORTANT:** If any check fails, fix the issue and re-run ALL checks — not just the failing one. Fixes often introduce new issues (e.g. adding properties breaks `sort-keys-fix`, prettier fixes change line structure). Repeat until all checks pass.

```
Run checks → failure? → fix → re-run ALL checks → still failing? → fix → re-run ALL checks → all green → commit & push
```

**Rule:** Only commit and push after a fully clean run where lint, types, and tests ALL pass with zero changes made after the checks completed.

## Important Notes

- Run checks in parallel using background Bash tasks for speed
- Only run checks for affected projects (don't test everything)
- Auto-fix lint issues when possible
- Skip `__generated__` directories — these are auto-generated
- **Pre-existing failures:** Some tests or type checks may fail due to missing generated files (e.g. `__generated__/graphql`). Run `nx run doctor` to fix. Compare against base branch to distinguish pre-existing vs new failures.
- **Lint warnings as errors in CI:** CI runs eslint without `--fix` so prettier formatting issues become errors. Always use `lint:ci` to catch these locally.

## Step 6: Offer Code Review

After all checks pass and before committing, ask the user if they'd like to run the `/requesting-code-review` skill to review the changes before committing. This is optional but recommended for larger changesets.

Now execute the pre-commit checks based on the current git state.
