You are diagnosing failed CI checks on a Nest monorepo PR.

## Step 1: Identify the PR

Determine the PR number. If the user provided a PR URL or number, use that. Otherwise, detect from the current branch:
```bash
gh pr view --json number,headRefName,url,statusCheckRollup --jq '{number, branch: .headRefName, url}'
```

If no PR exists for the current branch, tell the user and stop.

## Step 2: Get Check Status

List all CI checks and their status:
```bash
gh pr checks --json name,state,link --jq '.[] | select(.state != "SUCCESS" and .state != "SKIPPED") | {name, state, link}'
```

If all checks pass, report success and stop.

Categorize failures by job type:
| CI Job | Nx Command | Common Causes |
|--------|-----------|---------------|
| `test (project)` | `nx run <project>:test` | Failing unit tests, snapshot mismatches |
| `lint (project)` | `nx run <project>:lint:ci` | ESLint errors (no auto-fix in CI) |
| `check-types (project)` | `nx run <project>:check-types` | TypeScript errors, missing generated types |
| `build (project)` | `nx run <project>:build` | Import errors, missing deps, codegen issues |
| `identify-affected-projects` | Setup job | Install failure, prisma/codegen failure |
| `e2e (project)` | `nx run <project>:e2e:ci` | Playwright test failures |

## Step 3: Fetch Failure Logs

For each failed check, get the run logs:
```bash
# Get the workflow run ID from the latest failed run
gh run list --branch "$(git branch --show-current)" --status failure --limit 1 --json databaseId --jq '.[0].databaseId'

# View failed jobs in that run
gh run view <RUN_ID> --json jobs --jq '.jobs[] | select(.conclusion == "failure") | {name, conclusion}'

# Get logs for the failed job
gh run view <RUN_ID> --log-failed 2>&1 | head -200
```

Parse the logs to identify the specific errors. Look for:
- **Test failures**: `FAIL`, `Expected`, `Received`, test file paths
- **Lint errors**: ESLint rule names, file:line:col format
- **Type errors**: `error TS`, `Type '...' is not assignable`, file paths
- **Build errors**: `Module not found`, import resolution failures
- **Codegen errors**: `prisma generate`, `graphql-codegen` failures

## Step 4: Reproduce Locally

Run the failing check locally to confirm and get full output:

```bash
# For type errors — ensure generated types exist first
nx run client-api:prisma:generate
pnpm run generate-graphql-definitions
nx run <project>:check-types

# For lint
nx run <project>:lint   # local version auto-fixes; lint:ci does not

# For tests
nx run <project>:test   # or with pattern: nx run client-api:test <pattern>

# For build
nx run <project>:build
```

**IMPORTANT**: CI generates Prisma client and GraphQL types before running checks (they are gitignored). If you see type errors referencing `@generated` or `__generated__` paths, run codegen first:
```bash
nx run client-api:prisma:generate
pnpm run generate-graphql-definitions
```

## Step 5: Report and Fix

Present a summary:

```
🔍 PR Check Results — PR #<number>
──────────────────────────────────────
Branch: <branch-name>
Failed checks: <count>

❌ check-types (client-api)     — TS2322: Type 'string' not assignable to 'number' in src/foo.ts:42
❌ lint (patient-navigator)     — @typescript-eslint/no-unused-vars in src/bar.tsx:15
✅ test (client-api)            — passed
✅ build (provider-portal)      — passed
──────────────────────────────────────
```

Then for each failure:
1. Show the exact error with file path and line number
2. Read the failing file to understand context
3. Propose or apply the fix
4. Re-run the check locally to verify the fix

## Step 6: Verify All Checks Pass

After fixing, run all previously-failed checks to confirm:
```bash
# Run all failed checks in parallel using background tasks
nx run <project>:check-types &
nx run <project>:lint &
wait
```

Report final status. If all pass, the user can push and CI should go green.

## Common CI-Specific Gotchas

- **CI uses `lint:ci`** (no `--fix`, no cache) while local `lint` auto-fixes. Fix lint locally, commit the fix.
- **CI uses `--frozen-lockfile`** — if `pnpm-lock.yaml` is out of sync, install will fail. Run `pnpm install` locally and commit the lockfile.
- **CI generates types from scratch** — Prisma client and GraphQL types are gitignored. If a new field was added to schema.prisma or a .graphql file, CI handles codegen automatically, but type errors may surface if the codegen output changed.
- **patient-navigator lint:ci** runs extra checks: `check-story-schema-freshness`, `lint-stories-schema`, `lint-stories-connections`. If story types changed, run `nx run patient-navigator:generate-story-schema` and commit the updated schema.
- **Matrix jobs** — each affected project runs as a separate CI job. A failure in `test (client-api)` doesn't affect `lint (provider-portal)`.
- **Snapshot failures** — CI uploads snapshot artifacts on test failure. Check the `gh run view` artifacts if snapshot diffs are suspected.

Now diagnose the PR checks based on the current branch or the PR the user specified.
