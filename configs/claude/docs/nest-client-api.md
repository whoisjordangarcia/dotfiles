# Serving client-api: seed + index

Before or right after bringing up `serve:client-api` for an instance, check seed and index state and fix it automatically — don't wait to be asked.

Seed and indexes persist in the shared Postgres/ES, so this is once-off per instance. Skip when already populated.

## Checks

Both run against the instance's shared infra (Postgres 5432, ES 9244).

- **Seeded DB** has rows in `nestclientapi."Patient"`:
  ```bash
  psql … -tAc 'SELECT count(*) FROM nestclientapi."Patient"'   # > 0
  ```
- **Indexes exist** when the instance's ES prefix (`dev-<instance>-patients-v1`, etc.) returns docs.

## Fix

If either is empty, run with the instance env (shared-infra port overrides, same recipe as serving the API):

```bash
pnpm run seed
pnpm run index-all-records
```
