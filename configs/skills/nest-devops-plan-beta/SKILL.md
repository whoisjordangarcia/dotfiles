---
name: nest-devops-plan-beta
version: 0.5.0
description: Use when running terraform plan in the Nest monorepo's `infra/` tree to review pending infrastructure changes for tst or stg — covers `infra/app/` workspaces and the `infra/management/`, `infra/logging/`, `infra/elastic/` shared-infra stacks (Route53 records live inside management/). Auto-detects the `infra/` root inside the monorepo; plan-only and read-only; never runs apply, never targets prd, never bypasses or force-unlocks state locks.
---

## Preamble (run first)

```bash
# Telemetry is fire-and-forget: this block must never fail the caller,
# even under `set -euo pipefail`, outside a git repo, or before ~/.nest
# has been created. All failures are swallowed by the outer guard.
{
  mkdir -p ~/.nest/skill-analytics 2>/dev/null || true
  _AGENT="unknown"
  if [ "${CLAUDECODE:-}" = "1" ]; then
    _AGENT="claude-code"
  elif [ -n "${CURSOR_AGENT:-}" ]; then
    # Cursor sets CURSOR_AGENT during Agent (AI) sessions. See cursor.com/docs.
    _AGENT="cursor"
  elif [ -n "${CODEX_AGENT:-}" ] || [ -n "${CODEX_HOME:-}" ]; then
    # Codex does not publish a built-in 'I am running' env var. Users who
    # want reliable Codex attribution should add CODEX_AGENT=1 to their
    # ~/.codex/config.toml [shell_environment_policy].set table.
    _AGENT="codex"
  fi
  _BRANCH="$(git branch --show-current 2>/dev/null | tr -d '"\\' | head -c 100 || true)"
  if [ -z "$_BRANCH" ]; then _BRANCH="none"; fi
  printf '{"v":2,"skill":"nest-devops-plan-beta","version":"0.5.0","agent":"%s","ts":"%s","branch":"%s"}\n' \
    "$_AGENT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_BRANCH" \
    >> ~/.nest/skill-analytics/skill-usage.jsonl 2>/dev/null || true
} 2>/dev/null || true
```


# Nest DevOps — Terraform Plan (tst/stg, read-only)

## Overview

Walk the user through `terraform plan` in the Nest monorepo's **`infra/` tree** (auto-detected from `$PWD` or `$NEST_INFRA_ROOT`) so they can review pending infrastructure changes before another on-call engineer runs `apply`. Two stack shapes are in scope:

1. **`app/`** — workspace-based (`nest-tst` / `nest-stg`), uses env-specific `.tfvars` and `-secrets.tfvars`
2. **Shared-infra dirs** — `management/`, `logging/`, `elastic/` — single state, no workspaces, authenticates as `management-account-administrator-role`

This skill is **plan-only**. Apply is intentionally out of scope. Production (`nest-prd`) is intentionally out of scope.

## Hard Guards (refuse, do not rationalize)

| Request | Response |
|---------|----------|
| `terraform apply` | Refuse. Tell the user: "This skill is plan-only — run `./run-terraform-apply.sh` yourself if you're sure." |
| `./run-terraform-apply.sh ...` | Refuse for same reason. |
| `terraform workspace select nest-prd` | Refuse. Tell the user: "prd is out of scope for this skill." |
| `--var-file=prd*.tfvars` | Refuse. |
| Any prompt to "just plan prd to compare" | Refuse. Plan in prd still reads remote state and can mask drift detection elsewhere; stay out. |
| `terraform plan -lock=false` | Refuse. Resolve the lock the right way (see Handling state locks). |
| `terraform force-unlock` chained with the check that proves the lock is stale | Refuse. Run the check in its own command, inspect the output, then ask the user before unlocking. |
| Hardcoding an infra path (e.g. `~/projects/nest/infra`) | Refuse. Auto-detect (Step 0); the monorepo path differs per developer and per worktree. |

**Spirit of the guard:** if `prd`, `production`, `prod` appears in the env, workspace, profile, or tfvars name — stop and decline.

## Prerequisites

- The Nest **monorepo** is checked out locally somewhere (path varies per developer, and each worktree has its own `infra/` — see auto-detection below). The terraform stacks live under its `infra/` tree. Branch you trust (`git status` clean, or you understand the diff).
- `aws` CLI installed; SSO configured for `tst-account-administrator-role`, `stg-account-administrator-role`, and `management-account-administrator-role`
- `terraform` ≥ the version pinned in the repo (S3 state lockfile, provider `hashicorp/aws ~> 5.98 or 6.x`)
- `jq` available for parsing the JSON plan

## Step 0 — Detect the `infra/` root (do this first, every time)

**Never hardcode a path.** Find the `infra/` tree by signature, not by guessing. Inside the Nest monorepo the terraform lives under `infra/` — the dir that contains all of:

- `app/run-terraform-apply.sh`
- `management/`, `logging/`, `elastic/` (all three sibling dirs)
- An S3 backend config referencing the `nest-terraform-state-*` bucket

### Detection order

1. **Current working directory** — walk up from `$PWD` until you find a dir whose `app/run-terraform-apply.sh` exists.
2. **`$NEST_INFRA_ROOT` env var** — honor it if set.
3. **Ask the user** via `AskUserQuestion`. Do **not** hardcode any developer's path — paths differ per machine.

### Detection script

```bash
detect_infra_root() {
  # Walk up from PWD. The infra root is the dir that holds the terraform
  # stacks — inside the monorepo that's <monorepo>/infra. Match it whether
  # the user is already inside infra/ OR sitting at the monorepo root, and
  # walk-up naturally lands on the *current worktree's* infra/.
  local dir="$PWD" cand
  while [ "$dir" != "/" ]; do
    for cand in "$dir" "$dir/infra"; do
      if [ -f "$cand/app/run-terraform-apply.sh" ] \
         && [ -d "$cand/management" ] && [ -d "$cand/logging" ] \
         && [ -d "$cand/elastic" ]; then
        echo "$cand"; return 0
      fi
    done
    dir="$(dirname "$dir")"
  done
  # Honor explicit env var if set (point it at the infra dir, not the repo root)
  if [ -n "${NEST_INFRA_ROOT:-}" ] && [ -f "$NEST_INFRA_ROOT/app/run-terraform-apply.sh" ]; then
    echo "$NEST_INFRA_ROOT"; return 0
  fi
  return 1
}

INFRA_ROOT="$(detect_infra_root)" || {
  echo "Could not locate the infra/ root from \$PWD or \$NEST_INFRA_ROOT." >&2
  echo "Re-run this skill from inside the monorepo, or export NEST_INFRA_ROOT=<path-to-infra>." >&2
  exit 2
}
echo "Detected infra/ root at: $INFRA_ROOT"
```

If detection fails:
- Ask the user where the monorepo / `infra/` tree lives (via `AskUserQuestion`), then proceed. Do **not** ask once and then bake the answer into the skill — every session re-detects.
- If the user is in a different repo entirely, refuse and tell them this skill only operates on the monorepo's `infra/` tree.

### Confirmation guard

Even after detection, before doing anything destructive to local state, sanity-check the repo identity:

```bash
# Confirm this is the monorepo's infra tree, not a fork or a similarly-named project.
# Match the state-bucket family by prefix (no account id) — proves identity and
# survives an account migration.
grep -qE 'bucket[[:space:]]*=[[:space:]]*"nest-terraform-state-' "$INFRA_ROOT"/*/main.tf "$INFRA_ROOT"/*/*.tf 2>/dev/null \
  || { echo "REFUSED: detected dir does not reference the Nest terraform state bucket"; exit 2; }
```

## Flow A — `app/` plan for tst or stg

Run from `$INFRA_ROOT/app` (resolved by Step 0).

### Step 1: Confirm env and workspace with the user

> ⚠️ **APPROVAL GATE** — Use `AskUserQuestion` to confirm the target env (`tst` or `stg`) before doing anything destructive to local state (`rm -rf .terraform`).

### Step 2: SSO login (idempotent — safe to re-run)

```bash
ENV=tst   # or stg — NEVER prd
PROFILE=${ENV}-account-administrator-role

# Check if the session is still valid; only log in if it isn't.
if ! aws sts get-caller-identity --profile "$PROFILE" >/dev/null 2>&1; then
  aws sso login --profile "$PROFILE"
fi
```

If the user has not run `aws configure sso` for `$PROFILE` yet, this step will fail with a clear error — surface it and stop. Do not attempt to write SSO config on the user's behalf.

### Step 3: Re-init backend and select workspace

```bash
cd "$INFRA_ROOT/app"
rm -rf .terraform
terraform init -reconfigure
terraform workspace select "nest-${ENV}"   # nest-tst or nest-stg ONLY
```

**When to skip `rm -rf .terraform`:** if the user is already in `app/`, last ran plan against the same workspace, and providers haven't changed, the wipe + re-init costs minutes for no benefit. Ask before nuking `.terraform/` if it already exists.

### Step 3.5: Build generated artifacts that terraform plan reads

The `app/` stack references files that are **build artifacts**, not committed source:

- `app/step_functions/.tftpl/*.json.tftpl` — generated from ASL JSON by `scripts/step-functions.sh build`. Without these, `terraform plan` errors with `Invalid function argument ... no file exists at "./step_functions/.tftpl/<name>.json.tftpl"`.
- `app/cloudfront_functions/dist/*.js` — generated from `app/cloudfront_functions/src/*.js` by `cloudfront_functions/scripts/build.sh`. Plan may succeed without these, but apply will fail.

The repo's `run-terraform-apply.sh` does these builds before invoking terraform. A plan-only workflow must do the same:

```bash
cd "$INFRA_ROOT/app"
# Always-rebuild step function templates (idempotent; just regenerates files)
(cd "$INFRA_ROOT/app/cloudfront_functions" && ./scripts/build.sh) || { echo "BLOCKER: cloudfront_functions build failed"; exit 2; }
(cd "$INFRA_ROOT/app" && ../scripts/step-functions.sh build) || { echo "BLOCKER: step-functions build failed"; exit 2; }
```

These builds are **local-only file operations** — they don't call AWS, don't touch terraform state, don't run terraform commands. Safe to run on every plan.

**Do NOT** rebuild Lambda functions (`lambda_functions/scripts/build.sh`) as part of plan. The plan will surface `source_code_hash` diffs based on the current build artifacts, which is the *correct* signal for "Lambda code needs to be rebuilt before apply." Auto-rebuilding hides that signal.

### Step 4: Plan with env-specific tfvars

```bash
terraform plan \
  --var-file="${ENV}.tfvars" \
  --var-file="${ENV}-secrets.tfvars" \
  -out="/tmp/devops-app-${ENV}.tfplan"
```

The `-out` path lets the user (or another engineer) inspect the exact plan later with `terraform show /tmp/devops-app-${ENV}.tfplan`. **Do not** hand this plan file to anyone or stage it for apply yourself — that's still the user's call.

### Step 5: Review the plan with the user

See [Reviewing a plan](#reviewing-a-plan) below.

## Flow B — Shared-infra plan (`management/` / `logging/` / `elastic/`)

> Note: Route53 records and DNS validation live inside `management/route53.tf` — they're part of the `management` stack, not a separate dir. Plan `management/` to review Route53 changes.

These stacks have a **single state** (no workspaces) and run against the management account.

### Step 1: SSO login as management

```bash
PROFILE=management-account-administrator-role
if ! aws sts get-caller-identity --profile "$PROFILE" >/dev/null 2>&1; then
  aws sso login --profile "$PROFILE"
fi
```

### Step 2: Pick the directory with the user

> ⚠️ **APPROVAL GATE** — Use `AskUserQuestion` to confirm which dir: `management`, `logging`, or `elastic`. Do **not** loop through all three without asking.

### Step 3: Re-init and plan

```bash
DIR=management   # or logging / elastic
cd "$INFRA_ROOT/${DIR}"
rm -rf .terraform
terraform init -reconfigure
terraform plan -out="/tmp/devops-${DIR}.tfplan"
```

Some of these dirs (notably `management/`) take a `var.aws_profile`. If `terraform plan` errors with "No value for required variable", check `variables.tf` in the dir and pass `-var aws_profile=${PROFILE}` rather than guessing.

### Step 4: Review the plan with the user

See [Reviewing a plan](#reviewing-a-plan) below.

## Reviewing a plan

Plans in this repo are usually hundreds of lines. The goal of review is to make sure the user understands **every destroy and every replace before they happen**, plus any update that touches blast radius. Do not just paste the summary line and call it done.

### Step 1 — Always save plan to a file, then re-render structured

```bash
# (already done in the flow above)
terraform plan -out="/tmp/devops-app-${ENV}.tfplan" --var-file=... # etc.

# Human-readable re-render of the saved plan
terraform show "/tmp/devops-app-${ENV}.tfplan" > "/tmp/devops-app-${ENV}.plan.txt"

# Machine-readable JSON — this is what we'll grep/jq
terraform show -json "/tmp/devops-app-${ENV}.tfplan" > "/tmp/devops-app-${ENV}.plan.json"
```

### Step 2 — Categorize every change

Terraform's `resource_changes[].change.actions` tells you exactly what's happening per resource:

| Actions array | Symbol in text plan | Meaning | Risk |
|---------------|---------------------|---------|------|
| `["no-op"]` | (none) | Refreshed, unchanged | none |
| `["create"]` | `+` | New resource | low — unless name collides with something live |
| `["update"]` | `~` | In-place attribute change | **depends on which attribute** — see Step 3 |
| `["delete", "create"]` | `-/+` | **Destroy and recreate** | **high** — there's a window where the resource doesn't exist |
| `["create", "delete"]` | `+/-` | Create then destroy (rare) | medium — usually a `create_before_destroy` lifecycle |
| `["delete"]` | `-` | **Pure delete, no recreation** | **highest** — the resource is gone after apply |

Pull each bucket out by hand from the JSON:

```bash
PLAN=/tmp/devops-app-${ENV}.plan.json

echo "=== DESTROYS (no recreation) ==="
jq -r '.resource_changes[] | select(.change.actions == ["delete"]) | .address' "$PLAN"

echo "=== REPLACES (destroy + recreate) ==="
jq -r '.resource_changes[] | select(.change.actions == ["delete","create"] or .change.actions == ["create","delete"]) | .address' "$PLAN"

echo "=== UPDATES (in-place) ==="
jq -r '.resource_changes[] | select(.change.actions == ["update"]) | .address' "$PLAN"

echo "=== CREATES ==="
jq -r '.resource_changes[] | select(.change.actions == ["create"]) | .address' "$PLAN"
```

### Step 3 — For each destroy / replace, find *why*

A replace happens because at least one attribute is marked **"forces replacement"** in the diff. Find it:

```bash
# All resources being replaced, with the attribute(s) that forced it.
jq -r '
  .resource_changes[]
  | select(.change.actions == ["delete","create"] or .change.actions == ["create","delete"])
  | .address as $a
  | .change.replace_paths[]?
  | "\($a)  forces-replacement: \(.)"
' "$PLAN"
```

If `replace_paths` is empty for a replaced resource, the cause is at the resource level (often `count`/`for_each` shape change or a removed `lifecycle.create_before_destroy`). Open the text plan for that address and read the diff manually:

```bash
grep -A 80 "# <address> will be destroyed" "/tmp/devops-app-${ENV}.plan.txt"
grep -A 80 "# <address> must be replaced" "/tmp/devops-app-${ENV}.plan.txt"
```

### Step 4 — For each update, look at sensitive attributes

In-place updates are usually safe — but not always. These attribute changes are landmines even when the actions are `["update"]`:

| Resource type | Watch for | Why it matters |
|---------------|-----------|----------------|
| `aws_db_instance` / `aws_rds_cluster` | `engine_version`, `instance_class`, `parameter_group_name`, `apply_immediately` | May trigger maintenance window or short outage; engine bumps can be one-way |
| `aws_elasticache_cluster` / `_replication_group` | `node_type`, `engine_version`, `parameter_group_name` | Replication group changes can drop connections |
| `aws_ecs_service` | `desired_count → 0`, `deployment_minimum_healthy_percent`, `force_new_deployment` | Going to 0 takes the service down. Check before applauding "just a count change" |
| `aws_ecs_task_definition` | Image tag, env vars, secrets ARNs, IAM role | Image change rolls the service — usually fine, but verify the tag exists in ECR |
| `aws_iam_policy` / `_role` / `_role_policy` | Any `Statement` diff | Read the full statement — adding `"*"` resource or `"Action": "*"` is a privilege escalation |
| `aws_security_group_rule` / inline rules | `cidr_blocks`, `from_port`/`to_port` widening | Widening ingress = opening surface area |
| `aws_kms_key` | `policy`, `deletion_window_in_days`, `enable_key_rotation` | Key policy changes can lock out roles |
| `aws_route53_record` | `records`, `ttl`, `alias.name` | Wrong target = users hit the wrong cluster until TTL expires |
| `aws_cloudfront_distribution` | `origin.*`, `default_cache_behavior.*` | Cache behavior changes can break auth headers or POST handling |
| `aws_lambda_function` | `runtime`, `handler`, `layers`, `environment` | Runtime bumps can be breaking; layer ARN drift = redeploy needed |
| `aws_s3_bucket_policy` / `aws_s3_bucket_public_access_block` | Any diff | Public access surface |

Pull the per-attribute diff for any update you want to look at closely:

```bash
ADDR='aws_iam_role_policy.events_service'   # example
jq --arg a "$ADDR" '
  .resource_changes[]
  | select(.address == $a)
  | { before: .change.before, after: .change.after }
' "$PLAN"
```

### Step 5 — Drift detection

Some "updates" in a plan are **drift** — terraform is correcting state that someone changed in the AWS console or via another apply. Catch this by looking for changes the user didn't ask for:

- Ask the user: *"What change to the .tf files is supposed to drive this plan?"*
- Any resource changing that the user can't trace to a recent `.tf` edit is drift. Surface it explicitly; do not silently let `apply` revert someone else's intentional console edit.

```bash
# Show last commit touching .tf files — helps correlate plan diff with intent
git -C "$INFRA_ROOT" log -1 --name-only -- '*.tf'
```

### Step 6 — Downtime & intent verdict (bucket every change)

Categorization alone isn't enough — the operator wants to know **what would break, who would notice, and is any change unintended**. Bucket every resource change into one of the following. Use the resource type + the action to decide.

| Bucket | What lands in it | Verdict |
|--------|------------------|---------|
| **Hard downtime — needs explicit sign-off before apply** | Destroy of `aws_lb` / `aws_lb_listener` / `aws_lb_target_group` without a paired create. Destroy of `aws_wafv2_web_acl` that's still associated to a stage or distribution. Destroy or replace of `aws_db_instance` / `aws_rds_cluster`. Destroy of `aws_acm_certificate` while still referenced. | **Block.** Surface and require a human "yes, this is intentional and the maintenance window is X." |
| **DNS TTL outage** | Destroy of `aws_route53_zone`. `aws_route53_record` with changed `records`, `alias.name`, or `failover_routing_policy`. | Outage bounded by TTL (typically 60–300s). Verify nothing internal still resolves the affected name. |
| **Connection reset** | `aws_elasticache_replication_group` ↔ `aws_elasticache_cluster` swap. `engine_version` bump on `aws_db_instance` / `aws_rds_cluster` / `aws_elasticache_*`. RDS `apply_immediately = true` with non-cosmetic change. | Brief reconnect storm; usually seconds. Flag for off-hours apply if customer-facing. |
| **Rolling, controlled** | `aws_ecs_task_definition` replace. `aws_ecs_service` field change with sane `deployment_minimum_healthy_percent` (≥50%). `aws_api_gateway_deployment` replace. `aws_lambda_function` `source_code_hash` rotation. `aws_lambda_layer_version` replace. | Expected zero downtime *if* deployment health checks are configured. Note in summary, don't block. |
| **Cosmetic** | Tag-only changes. `aws_cloudwatch_log_group` retention / KMS. `aws_lambda_function` `last_modified`. `aws_api_gateway_stage` `deployment_id`. CloudWatch alarm threshold tweaks that don't change paging. | Zero downtime, zero risk. Omit from the verdict summary unless count > 20. |
| **Intent check — drift / untraced** | Any change whose corresponding resource hasn't been touched by a commit on the current branch (or any commit since the last successful apply, if known). | **Flag every entry by address.** Apply would *revert* something the agent didn't author. |

#### How to populate the verdict from JSON

```bash
PLAN=/tmp/devops-app-${ENV}.plan.json

# Hard-downtime candidates (destroy actions on critical infra without paired create)
jq -r '
  .resource_changes[]
  | select(.change.actions == ["delete"])
  | select(.type | test("^(aws_lb|aws_lb_listener|aws_lb_target_group|aws_wafv2_web_acl|aws_db_instance|aws_rds_cluster|aws_acm_certificate)$"))
  | .address
' "$PLAN"

# DNS TTL outage candidates
jq -r '
  .resource_changes[]
  | select(.change.actions != ["no-op"] and .change.actions != ["create"])
  | select(.type | test("^aws_route53_(zone|record)$"))
  | .address
' "$PLAN"

# Connection-reset candidates
jq -r '
  .resource_changes[]
  | select(.change.actions != ["no-op"])
  | select(.type | test("^(aws_elasticache_replication_group|aws_elasticache_cluster|aws_db_instance|aws_rds_cluster)$"))
  | .address
' "$PLAN"
```

#### Resolving "Hard downtime" cases against intent

For every Hard-downtime entry, dig one level deeper before concluding it's unsafe:

1. **Is there a paired create on the same logical name?** A `aws_lb.foo` destroy with a `aws_lb.foo_v2` create can be coordinated (point DNS, drain old). Surface this pairing in the summary so the operator can plan it.
2. **Is the destroy on a feature/teardown PR?** Check `git log -p --follow <relevant .tf file>` for a commit that explicitly removes the resource. If the destroy traces to "remove internal API stack" with author + PR link, that's intent — surface the PR link.
3. **If neither**, treat as accidental and refuse to summarize as routine.

### Step 7 — Hand back a structured summary

A good summary names every destroy and replace, flags the highest-risk update, and answers "what could break and when":

> **Plan against `nest-tst` (app/)** — 3 to add, 7 to change, **2 to destroy, 1 to replace**.
>
> **Destroys (gone after apply):**
> - `aws_cloudwatch_log_group.legacy_events` — confirm no dashboards/alarms still reference it
>
> **Replaces (brief outage window):**
> - `aws_ecs_task_definition.events_service` — `-/+` because `family` changed. Service `events-service` will roll; expect ~1m of in-flight task drain.
>
> **Updates worth a second look:**
> - `aws_iam_role_policy.events_service` — adds `s3:GetObject` on `nest-tst-events-*`. Scope is `tst` only.
> - `aws_security_group_rule.bastion_ingress` — widening cidr from `10.0.0.0/16` → `10.0.0.0/8`. Is that intentional?
>
> **No drift detected against last .tf commit** (`abc1234 feat: add events-service s3 read`).
> **No prd touched. No apply performed.**

A concise hand-back for a *clean* plan looks like:

> Plan against `nest-stg` (app/): **0 destroys, 0 replaces, 2 in-place updates** (ECS task def image bump on `web` and `worker`). Low risk; no apply performed.

#### Verdict-style hand-back (preferred when there are destroys or replaces)

When the plan contains any destroy or replace, structure the summary around the verdict buckets — not the raw counts. Example:

> **Plan against `nest-tst` (app/)** — 1 add, 12 change, 15 destroy.
>
> **Bottom line:** destroys are intended (all trace to PR #345). Customer-facing downtime: **none** (private zone). Internal API surface downtime: **immediate on apply** for anything resolving `tst.api-internal.nestgenomics.com`. Two items need eyes-on before apply.
>
> **Hard downtime — sign-off needed:**
> - `aws_wafv2_web_acl.api_gateway_waf` destroyed (still associated to API Gateway). Confirm protection is moved to CloudFront WAF or that removal is deliberate.
> - `aws_lb.client_api_internal_alb` destroyed (no paired create). Internal API surface goes dark.
>
> **DNS TTL outage:**
> - `aws_route53_zone.api_internal_private_zone` destroyed → 2 records gone. Grep app repo for `api-internal.nestgenomics.com`.
>
> **Connection reset:** none this run.
>
> **Rolling / controlled:**
> - `aws_ecs_service.nest_client_api_service` `load_balancer` change (paired with the ALB destroy)
> - `aws_api_gateway_deployment` replace
>
> **Cosmetic:** 11 Lambda source_code_hash rotations + 1 API gateway stage deployment_id (CI build churn — verify the build is from the expected commit before apply).
>
> **Intent check / drift:** **none.** Every change traces to commit `7d6b600` on the current branch's merge base.
>
> **Artifacts:** /tmp/devops-app-tst.{tfplan,plan.txt,plan.json}. No apply performed. No prd touched. No lock bypass.

The verdict format makes the operator's first question — *"can I apply this without a maintenance window?"* — readable in two seconds.

## Quick reference

| What | tst | stg | prd |
|------|-----|-----|-----|
| `app/` workspace | `nest-tst` | `nest-stg` | **refuse** |
| `app/` tfvars | `tst.tfvars`, `tst-secrets.tfvars` | `stg.tfvars`, `stg-secrets.tfvars` | **refuse** |
| AWS profile | `tst-account-administrator-role` | `stg-account-administrator-role` | **refuse** |
| Shared-infra profile | `management-account-administrator-role` | same | same |
| Apply | **never (this skill)** | **never (this skill)** | **never (this skill)** |

## Handling state locks (the 412 PreconditionFailed signal)

This repo uses **S3-native state locking** (`use_lockfile = true`), not DynamoDB. A lock conflict surfaces as:

```
Error: Error acquiring the state lock
... api error PreconditionFailed: At least one of the pre-conditions you specified did not hold
Lock Info:
  ID:        <uuid>
  Path:      nest-terraform-state-<ACCOUNT_ID>/env:/<workspace>/<key>
  Operation: OperationTypeApply | OperationTypePlan
  Who:       <user>@<host>
  Created:   <timestamp>
```

### Rules (hard, not negotiable)

- **Never pass `-lock=false`** to `terraform plan`. The lock exists to prevent state corruption; bypassing it is the same class of mistake as `--no-verify`.
- **Never run `terraform force-unlock` without first proving the lock is stale.** A live apply by another engineer (or by the current user in another shell) **MUST** be allowed to finish — concurrent state writes are how state files get corrupted.

### Proving the lock is stale before unlocking

A lock is safe to release only when **all** of the following are true:

1. The lock's `Who` field is the current user on the current host (`whoami@$(hostname)`), AND
2. There is no live terraform process anywhere on the machine. **Filter on `comm` (process basename), not on the full args**, otherwise the check can self-match when your prompt or task description contains the strings `terraform apply` / `terraform plan`:
   ```bash
   # Matches a real `terraform apply|plan` binary OR the `sh run-terraform-apply.sh` wrapper.
   # Filters on `comm` (basename) so it won't match an editor or agent that just mentions "terraform" in its args.
   ps -eo pid,etime,comm,args | awk 'NR > 1 && (
       ($3 == "terraform" && ($4 == "apply" || $4 == "plan")) ||
       ($3 == "sh" && $0 ~ /run-terraform-apply\.sh/)
     )'
   ```
3. **Run that check in its own command — not chained with anything destructive.** Inspect the output, confirm "no live terraform processes", and only then proceed.
4. The lock's `Operation` is `Apply` and the timestamp is older than the longest apply you've ever seen against this repo (a 20-minute-old `Apply` lock is **not** stale — it may be a normal long-running apply).
5. If the user is on the on-call rotation or there's any sign of CI activity (`gh run list --workflow=ci.yml --limit 5`), do not release — coordinate first.

### Approval gate

> ⚠️ Even after the checks pass, use `AskUserQuestion` to get explicit human approval before running `terraform force-unlock`. Show them the lock metadata in the prompt. Do not chain the unlock with anything else.

### After a force-unlock

If you released a lock that turned out to belong to a live apply:

1. **Do not start any new terraform operation** against the same workspace until the live apply finishes.
2. Wait for the apply process to exit naturally. Do not `kill` it — interrupting mid-write is worse than letting it complete.
3. Once it exits, run `terraform state list | wc -l` and compare to recent values (you can pull historical state-list counts from your own scratch notes or from the previous successful plan). A large unexplained change is a red flag — escalate before doing anything else.

## Red flags — STOP and decline

- User asks to "just apply this tiny change" → decline; this skill is plan-only.
- User asks to plan `nest-prd` "to compare with tst" → decline; prd is out of scope.
- `terraform apply` shows up anywhere in your proposed shell → delete it; re-read this skill.
- You're about to write to `$INFRA_ROOT/app/prd.tfvars` or `$INFRA_ROOT/app/prd-secrets.tfvars` → stop.
- You're about to run `run-terraform-apply.sh` → stop; that script is interactive and runs `apply`.
- You're about to pass `-lock=false` to `terraform plan` → stop; resolve the lock the right way (see Handling state locks).
- You're about to chain `pgrep`/`ps` with `terraform force-unlock` in one command → split them; the check must complete and be visually verified before any unlock runs.
- You can't auto-detect the `infra/` root and you're tempted to `cd ~/projects/nest/infra` anyway → stop; that path is developer- and worktree-specific. Ask.

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Running `terraform plan` before `workspace select` in `app/` | Plans against whichever workspace was last selected (often `default`) — always select workspace first |
| Forgetting `-secrets.tfvars` in `app/` | `terraform plan` errors with "No value for required variable" — pass both files |
| Re-running `rm -rf .terraform` between every plan | Wastes time re-downloading providers; only needed when switching dirs or after backend config changes |
| Plain `terraform plan` in `management/` with no AWS profile loaded | Fails with `NoCredentialProviders` — run `aws sso login --profile management-account-administrator-role` first |
| Bundling all four shared-infra dirs into one `for` loop without asking | Each has its own state and review surface — ask which dir, plan one at a time |
| Saving the plan output file inside the repo | Stays in untracked state and can leak secrets; write to `/tmp/` instead |
| Treating drift as noise | Drift = someone else's change. Surface it; don't auto-accept |
| Reading only the summary line ("3 to change") | Look at each change. `update` on IAM/SG/RDS/KMS can be as destructive as `destroy` |
| Confusing `-/+` (replace) with `~` (in-place update) | Replace destroys the resource first — there is an outage window. In-place doesn't |
| Skimming past `# forces replacement` | That comment is why a resource is being recreated. Always identify the trigger attribute |
| Ignoring sensitive-attribute updates because actions say "update" | An `aws_iam_policy` update can grant `"*"` — read the full statement diff, not just the action verb |
| Force-unlocking a "stale" lock without checking for live processes | A 20-minute-old `Apply` lock can be a legitimate long-running apply. Always run `ps`/`pgrep` in a separate command and inspect the output before unlocking |
| Assuming `infra/` lives at a fixed path | Paths differ per developer and per worktree. Use Step 0 auto-detection; ask the user if detection fails |
| Live-process check that greps the full command line (e.g. `ps \| grep 'terraform apply'`) | Self-matches any agent or editor whose prompt text mentions `terraform apply`. Filter on `comm` (process basename) instead, as shown in the lock-handling section |
| Running `terraform plan` in `app/` without first running the pre-plan builds | Fails with `templatefile ... no file exists at .../step_functions/.tftpl/<name>.json.tftpl`. The `.tftpl` files are generated by `scripts/step-functions.sh build`; cloudfront_functions need their own build too |
| Auto-rebuilding Lambda code as part of plan | Hides the `source_code_hash` diff that tells you "code needs rebuild before apply." Leave Lambda builds out of the plan flow |
