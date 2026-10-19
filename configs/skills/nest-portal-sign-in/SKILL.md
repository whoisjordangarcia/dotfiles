---
name: nest-portal-sign-in
description: Sign into the Nest provider portal or patient navigator in any environment — local dev, STG, or TST — using browser automation. Use when asked to sign in, login, or authenticate to the provider portal or patient navigator; when validating/verifying/testing a UI change; or during acceptance testing on STG/TST. Triggers on: sign in to portal, login to portal, portal sign in, authenticate portal, open portal, validate portal change, verify portal UI, check portal, test portal feature, sign in to stg portal, sign in to tst portal, acceptance testing on stg, validate on stg, validate on tst, sign in as patient, patient login, open patient navigator, test patient app, patient sign in.
version: 0.3.0
user-invocable: true
---

# Portal Sign-In

Signs into the Nest provider portal across environments. The flow is **the same everywhere** — a Frontegg two-step form (email → password). The only per-environment differences are the credentials file, the base URL, and (for local dev only) port detection.

## Environments

| Env | Creds file | Portal login URL | Port |
|-----|-----------|------------------|------|
| **dev** (default) | `~/.config/nest-skills/portal-sign-in.env` | `https://dev.portal.nestgenomics.com:{port}/account/login` | detect (below) |
| **stg** | `~/.config/nest-skills/stg-portal-sign-in.env` | `https://stg.portal.nestgenomics.com/account/login` | none (hosted) |
| **tst** | `~/.config/nest-skills/tst-portal-sign-in.env` | `https://tst.portal.nestgenomics.com/account/login` | none (hosted) |

**Choosing the environment:** use the one the user names. "Validate NES-XXXX on stg", "acceptance testing on stg", "check this on tst" → that env. If none is named, default to **dev**. Only dev needs port detection; stg and tst live at fixed hosted URLs.

All three creds files use the same keys: `PORTAL_EMAIL` and `PORTAL_PASSWORD`. STG/TST credentials are the hosted portal logins, not local ones.

## Setup

Load the target environment's creds file (dev shown; swap the filename per the table above):

```bash
# ENV_FILE = the row's creds file, e.g. ~/.config/nest-skills/stg-portal-sign-in.env for stg
ENV_FILE=~/.config/nest-skills/portal-sign-in.env
PORTAL_EMAIL=$(bash -c "source $ENV_FILE 2>/dev/null && echo \"\$PORTAL_EMAIL\"")
PORTAL_PASSWORD=$(bash -c "source $ENV_FILE 2>/dev/null && echo \"\$PORTAL_PASSWORD\"")
```

If that env's file is missing or empty, ask the user for **that environment's** portal email and password, then save them:

```bash
mkdir -p ~/.config/nest-skills
cat > "$ENV_FILE" << EOF
PORTAL_EMAIL=<email>
PORTAL_PASSWORD=<password>
EOF
```

Then retry the original request.

**Browser tool** — try in order, use whichever loads: `Skill(agent-browser)` → Playwright MCP (`mcp__playwright`). If none of those are installed, fall back to any browser automation built into the agent. Only if there is no way to drive a browser at all, tell the user.

## Port detection (dev only)

STG and TST use the fixed URLs above — skip this section for them.

For local dev, detect the port before building the URL. In a git worktree it lives in `tools/stack/.env.<worktree-name>`:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
WORKTREE_NAME=$(basename "$REPO_ROOT")
WORKTREE_ENV="$REPO_ROOT/tools/stack/.env.${WORKTREE_NAME}"

# Worktree-specific env takes priority, then .env.local, then default 3001
if [ -f "$WORKTREE_ENV" ]; then
  PORT=$(grep -E "^PROVIDER_PORTAL_PORT=|^PORTAL_PORT=" "$WORKTREE_ENV" 2>/dev/null | head -1 | cut -d'=' -f2 | tr -d '"' | tr -d "'" | tr -d ' ')
else
  PORT=$(bash -c 'source apps/frontend/provider-portal/.env.local 2>/dev/null && echo "${PORTAL_PORT:-3001}"')
fi
PORT=${PORT:-3001}
lsof -i :$PORT -sTCP:LISTEN 2>/dev/null | head -2
```

If nothing is listening on dev: start the apps — run `pnpm run serve:all` (client-api, provider-portal, patient-navigator, yoda) in the background, wait for the port to start listening, then continue. Use `nx serve provider-portal` if only the portal is needed.

## Login Flow

Headless by default; headed only if the user explicitly asks. Identical across all environments.

The login page also shows a **Google** SSO button — never use it. Always sign in through the email/password form with the stored credentials:

1. Navigate to the environment's login URL (from the table; dev fills in `{port}`)
2. Fill the email field with `$PORTAL_EMAIL`, click Continue
3. Fill the password field with `$PORTAL_PASSWORD`, click Sign in
4. If a **Select Account** dialog appears (users belonging to multiple accounts get one), keep the preselected account unless the user named a different one, then click Continue
5. Wait for the URL to change away from `/account/login`

**Success**: URL changed → report the new URL.
**Failure**: URL unchanged → report it. Do not retry.

The Frontegg form may be invisible to accessibility-tree/DOM element readers (shadow DOM) — if element lookups come up empty, drive it from a screenshot using coordinates.

If a login presents a form that differs from this flow (e.g. an added MFA step), report what you saw rather than guessing.

## Errors

| Failure | Action |
|---------|--------|
| Credentials missing | Ask the user for that environment's email and password, then create its `*-portal-sign-in.env` file |
| No browser tool | Ask the user to configure Agent Browser or Playwright MCP |
| Portal not running (dev) | Run `pnpm run serve:all` in the background, wait for the port, retry |
| Login form not found | Reload the login URL once; if still missing, report what loaded instead |
| Login failed | Report it — wrong credentials or an MFA/Frontegg issue. Do not retry |

---

# Patient Navigator Sign-In

Signs into the patient navigator app as a specific patient. This requires the provider portal to generate a magic sign-in link, so the portal login flow above is a prerequisite. Works in any environment — substitute `{env}` (`dev` / `stg` / `tst`) into the hostnames below.

## Prerequisites

- Provider portal signed in (see above)
- Patient navigator reachable — stg/tst: hosted
- Client API reachable — stg/tst: hosted

On dev, if any of these aren't running, start them: `pnpm run serve:all` covers everything this flow needs (client-api, provider-portal, patient-navigator); individually: `nx serve patient-navigator`, `nx serve client-api`.

## Hostnames per environment

| Env | API (sign-in link) | Patient navigator |
|-----|--------------------|-------------------|
| dev | `https://dev.api.nestgenomics.com:{api_port}` | `https://dev.app.nestgenomics.com:{patient_port}` |
| stg | `https://stg.api.nestgenomics.com` | `https://stg.app.nestgenomics.com` |
| tst | `https://tst.api.nestgenomics.com` | `https://tst.app.nestgenomics.com` |

For dev, detect the ports (same pattern as the portal). STG/TST are hosted — no ports:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
WORKTREE_NAME=$(basename "$REPO_ROOT")
WORKTREE_ENV="$REPO_ROOT/tools/stack/.env.${WORKTREE_NAME}"

if [ -f "$WORKTREE_ENV" ]; then
  PATIENT_PORT=$(grep -E "^PATIENT_NAVIGATOR_PORT=|^PATIENT_PORT=" "$WORKTREE_ENV" 2>/dev/null | head -1 | cut -d'=' -f2 | tr -d '"' | tr -d "'" | tr -d ' ')
  API_PORT=$(grep -E "^CLIENT_API_PORT=|^API_PORT=" "$WORKTREE_ENV" 2>/dev/null | head -1 | cut -d'=' -f2 | tr -d '"' | tr -d "'" | tr -d ' ')
fi
PATIENT_PORT=${PATIENT_PORT:-3002}
API_PORT=${API_PORT:-3000}
```

## Login Flow

The patient navigator uses magic sign-in links (no email/password). The flow:

1. **Sign into the provider portal** first (use the Portal Login Flow above, same environment). Use a headed, non-incognito session.
2. **Navigate to a patient** — click on a patient row in the Patients list, or search for a specific patient.
3. **Open Invite Patient dialog** — on the patient detail page, find the Actions menu (ellipsis/three-dot button) and click "Invite Patient", or look for an existing invite link.
4. **Extract the sign-in link** — the dialog shows a sign-in link like `{api-host}/signin-link/{token}` (see the hostname table). Extract this URL.
5. **Open in a separate incognito browser session** — use a new browser session with incognito/private mode so it doesn't share cookies with the provider portal session:
   ```bash
   # agent-browser example:
   agent-browser --headed --session patient --args "--incognito" open "<sign-in-link>"
   ```
6. **Wait for redirect** — the API redirects to the patient navigator. Wait for the URL to land on the env's patient-navigator host.

**Success**: URL contains the patient-navigator host and is no longer on the sign-in link.
**Failure**: Check that the API is reachable and the sign-in link hasn't expired.

## Choosing a Patient

If the user doesn't specify a patient, pick the first patient in the list. If they ask for a specific patient, use the search box on the Patients page to find them.

## Testing Stories

Once signed into the patient navigator, you can open stories directly via URL hash (substitute the env's patient-navigator host):

```
{patient-nav-host}/#/story/{story-id}
```

The **module-debugger** story is a built-in test harness that includes all chapter types (history collection, care plans, etc.) and is useful for testing story player features:

```
{patient-nav-host}/#/story/module-debugger
```

The **animation-demo** story (if present) tests animation features specifically:

```
{patient-nav-host}/#/story/animation-demo
```

Story JSON files live in `apps/frontend/patient-navigator/src/data/`.

## Errors

| Failure | Action |
|---------|--------|
| Patient navigator not running (dev) | Run `pnpm run serve:all` (or `nx serve patient-navigator`) in the background, wait, retry |
| Client API not running (dev) | Run `pnpm run serve:all` (or `nx serve client-api`) in the background, wait, retry |
| Sign-in link expired | Generate a fresh one from the patient detail page |
| No Invite Patient option | Patient may lack an email — pick a different patient (if a specific one was requested, report instead) |
| Redirect failed | Re-check the env's API and patient-navigator hosts/ports, retry once |
