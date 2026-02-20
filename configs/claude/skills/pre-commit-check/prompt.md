You are running pre-commit quality checks on the Nest monorepo.

## Step 1: Verify Pre-Commit Hooks

Check that husky is installed and the pre-commit hook exists:
```bash
test -f .husky/pre-commit && echo "✅ Husky pre-commit hook exists" || echo "❌ Missing! Run: pnpm run setup-hooks"
```
If missing, run `pnpm run setup-hooks` to enable husky. The hook runs `lint-staged` which handles eslint, prettier, type checks, and story schema linting on staged files.

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
| `apps/frontend/patient-navigator/` | `patient-navigator` | check-types, lint |
| `apps/frontend/provider-portal/` | `provider-portal` | check-types, lint |
| `libs/` | Affected libs | check-types |

Additional checks based on file types:
- `*.story.json` changed → run `nx run patient-navigator:lint-stories-schema`
- `*.gql` or `graph.gql` changed → run `pnpm run generate-graphql-definitions` first
- `schema.prisma` changed → run `nx run client-api:migrate:dev` first
- `__generated__/` files changed → remind user to run `pnpm run generate-graphql-definitions`

## Step 3: Run Checks in Parallel

For each affected project, run checks **in parallel** using background Bash tasks:

1. **Lint** (with auto-fix): `nx run <project>:lint`
2. **Type check**: `nx run <project>:check-types`
3. **Unit tests** (backend only): `nx run client-api:test`
4. **Story schema lint** (if story files changed): `nx run patient-navigator:lint-stories-schema`

Run all independent checks simultaneously. Collect results.

## Step 4: Report Results

Provide a clear summary table:

```
🔍 Pre-Commit Checks
──────────────────────────────────────
Base branch: release/X.X.X
Changed projects: client-api, patient-navigator

✅ Lint (patient-navigator)          passed
✅ Type Check (patient-navigator)    passed
✅ Unit Tests (client-api)           3590 passed
⚠️ Type Check (client-api)          FAILED (pre-existing on base branch)

──────────────────────────────────────
Result: ✅ Ready to commit (failures are pre-existing)
```

## Step 5: Distinguish Pre-Existing vs New Failures

If a check fails, determine whether the failure is **pre-existing on the base branch** or **introduced by this branch**:
- Check if the failing files were modified by this branch
- If errors are in files NOT touched by this branch, flag as "⚠️ pre-existing"
- Only block commit for failures **introduced by this branch**

## Important Notes

- Run checks in parallel using background Bash tasks for speed
- Only run checks for affected projects (don't test everything)
- Auto-fix lint issues when possible
- For `client-api:test`, if only specific test files changed, run those: `nx run client-api:test <pattern>`
- Skip `__generated__` directories — these are auto-generated

Now execute the pre-commit checks based on the current git state.
