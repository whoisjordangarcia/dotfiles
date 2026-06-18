---
name: nest-pr-analysis-beta
version: 0.1.0
description: Use when the user asks for a PR analysis, PR stats, review-load report, cycle-time/time-to-merge breakdown, area-of-work summary, or "what shipped" review on the Nest-Genomics/nest repo. Triggers on "PR analysis", "PR stats", "time to merge", "review load", "who reviewed what", "what shipped last month", "PR dashboard".
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
  printf '{"v":2,"skill":"nest-pr-analysis","version":"0.1.0","agent":"%s","ts":"%s","branch":"%s"}\n' \
    "$_AGENT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_BRANCH" \
    >> ~/.nest/skill-analytics/skill-usage.jsonl 2>/dev/null || true
} 2>/dev/null || true
```


# Nest PR Analysis

Build an interactive HTML dashboard summarizing pull-request activity on the Nest repo over an arbitrary date window. Output: a single self-contained `.html` file with click-to-drill-down charts, plus optional upload to the team docs site via `nest-summary-html`.

## When to Use

- "PR analysis for the past N months/weeks"
- "Who's reviewing what / time to merge / cycle time"
- "Area-of-work breakdown" or "what areas did we ship in"
- Quarterly retros, manager 1:1 prep, eng-org health snapshots
- The user provides a date range and asks for engineering-throughput stats

**Not for:** single-PR summaries (use `gh pr view`), release notes (use `nest-release-summary`), or live build-failure triage (use `pr-check`).

## What This Skill Produces

A single self-contained `.html` file styled to match `nest-summary-html` (Instrument Serif H1 with the brand orange→purple gradient, white background, the gear-icon settings panel with 5 themes × 3 modes × 3 widths, a sidebar TOC). Contents:

1. **Window selector** — five buttons (Past week / 2 weeks / month / 2 months / All captured) with date-range display. **Recomputes every chart, percentile, and table client-side from a filtered PR set.** No regeneration required. Header note shows how many release/merge PRs were excluded from analytics.
2. **KPI strip** — total PRs, merge rate, median TTM/review/approval times, no-human-engineer-reviewer count
3. **Live signals** — review queue (open PRs awaiting review, oldest 8) and stuck-in-draft list (drafts open >7 days). Actionable for whoever is on review duty right now.
4. **Cycle time** — p50/p75/p90/max for time-to-first-review, time-to-first-approval, time-to-merge, approval→merge. Median TTM by author + slowest-merges table.
5. **CI duration** — percentiles + distribution + per-step breakdown (top 25 jobs, p50 + p90 dual bars). Cursor-bot automation steps shown in muted gray with 🤖 prefix; real gating CI in brand orange.
6. **Iteration & PR-size signals** — comments per PR, commits per PR, lines-changed buckets (all clickable), most-iterated and highest-churn tables, comments-per-kLOC by size bucket (rubber-stamp signal), PR size vs TTM scatter (color by area, click to open).
7. **Areas of work** — stacked area chart (PRs by area, segmented by author), bus-factor heatmap (per-area top-author ownership %, color-coded green→yellow→orange→red), author × reviewer collaboration matrix, area × engineer attribution table.
8. **Volume & ownership** — state donut, reviewer + author leaderboards, reviewer responsiveness table (median time-to-first-review per reviewer with bar chart), daily-volume line chart with three series (Ready / Merged / Drafts), day-of-week × hour merge heatmap.
9. **Sidebar TOC with scroll-spy** — collapses to a chevron pill.
10. **Click-to-drilldown modal** — every author/reviewer/area chip and every distribution bar opens a filtered PR list with GitHub links and per-PR detail.
11. **Findings & recommendations** — agent-authored editorial section at the end with 5–8 data-grounded findings, process-change recommendations (gold/silver/bronze ranked), and a "Pick one" callout naming the highest-leverage move. **This is the leadership-readable narrative layer over the raw stats.**

**Filters baked in by default:**
- **Release/merge PRs are excluded from all analytics.** RC and stg→release merges have hundreds of commits, no real review, and merge in seconds — keeping them in distorts every cycle-time, churn, and size metric. The header notes how many were excluded for transparency.
- **Cursor + GitHub bots** are filtered out of human-reviewer counts.
- **Product team** (`caitlinbinder`, `emiliesimmons`, `lauraehayward16`) is excluded from review-load metrics — they're not part of the engineering review cycle.

## Process

### Step 1 — Confirm scope with the user

Ask (or infer from the request):
- **Date window** — default: past 2 months ending today
- **Repo** — default: `Nest-Genomics/nest`
- **Output path** — default: `~/Desktop/nest-pr-analysis/index.html`
- **Upload to S3 after?** — default: ask after generating

### Step 2 — Fetch PR metadata in date-window chunks

GitHub's GraphQL endpoint **404s/504s** if you ask for too many PRs with nested `reviews` and `reviewRequests` in one query. Always chunk by ~5–10 day windows.

```bash
mkdir -p /tmp/pr_chunks
for range in "2026-03-05..2026-03-10" "2026-03-11..2026-03-15" \
             "2026-03-16..2026-03-25" "2026-03-26..2026-03-30" \
             "2026-03-31..2026-04-04" "2026-04-05..2026-04-09" \
             "2026-04-10..2026-04-14" "2026-04-15..2026-04-19" \
             "2026-04-20..2026-04-24" "2026-04-25..2026-05-05"; do
  out=/tmp/pr_chunks/${range//../_}.json
  gh pr list --state all --search "created:$range" --limit 100 \
    --json number,title,author,createdAt,mergedAt,state,isDraft,reviewRequests,reviews,additions,deletions,labels \
    > "$out" 2>&1
  # If a window 502s, retry with a smaller window.
done

# Validate (502s land as text, not JSON):
for f in /tmp/pr_chunks/*.json; do head -c1 "$f" | grep -q '\[' || echo "BAD: $f"; done

# Merge & dedupe by number
jq -s 'add | unique_by(.number)' /tmp/pr_chunks/*.json > /tmp/nest_all.json
jq 'length' /tmp/nest_all.json
```

**Do NOT** include `commits` or `comments` fields in this query — they explode the GraphQL node count and produce `By the time this query traverses to the authors connection, it is requesting up to 1,000,000 possible nodes which exceeds the maximum limit of 500,000.`

### Step 3 — Fetch iteration data per PR via REST (parallel)

`gh api repos/.../pulls/:n` returns `comments`, `review_comments`, `commits`, and `changed_files` in one call. Parallelize 12-way.

```bash
mkdir -p /tmp/pr_iter
jq -r '.[].number' /tmp/nest_all.json > /tmp/pr_numbers.txt

cat /tmp/pr_numbers.txt | xargs -P 12 -I{} sh -c '
  n="$1"; out=/tmp/pr_iter/$n.json
  [ -s "$out" ] || gh api "repos/Nest-Genomics/nest/pulls/$n" \
    --jq "{number,comments,review_comments,commits,changed_files}" > "$out" 2>/dev/null
' _ {}

jq -s '.' /tmp/pr_iter/*.json > /tmp/nest_iter_all.json
```

**Important:** Use `sh -c '...' _ {}` form. `xargs -I{}` with a bash function exported via `export -f` does **not** propagate into subshells reliably — the simpler `sh -c` form always works.

### Step 3b — Fetch CI durations per PR (parallel)

GitHub returns `started_at`/`completed_at` for every check run on a commit. The walltime of the **longest** single check run is the actual CI gating time. Two API calls per PR (one to get `head.sha`, one for check-runs).

```bash
mkdir -p /tmp/pr_ci
cat > /tmp/fetch_ci.sh << 'EOF'
#!/bin/bash
n="$1"; out="/tmp/pr_ci/$n.json"
[ -s "$out" ] && exit 0
sha=$(gh api "repos/Nest-Genomics/nest/pulls/$n" --jq ".head.sha" 2>/dev/null)
if [ -z "$sha" ]; then echo "{\"number\":$n}" > "$out"; exit 0; fi
gh api "repos/Nest-Genomics/nest/commits/$sha/check-runs?per_page=100" \
  --jq "{
    number: $n,
    n_runs: (.check_runs | length),
    runs: [.check_runs[] | select(.started_at and .completed_at) | {
      name, sec: ((.completed_at|fromdateiso8601) - (.started_at|fromdateiso8601)), conclusion
    }]
  }" > "$out" 2>/dev/null
EOF
chmod +x /tmp/fetch_ci.sh
cat /tmp/pr_numbers.txt | xargs -P 12 -I{} /tmp/fetch_ci.sh {}

# Compute longest-job duration per PR (the actual gating time)
jq -s '[.[] | select(.runs and (.runs|length>0)) | {
  number, n_runs,
  ci_min: (([.runs[].sec] | max) / 60 | round),
  passed: ([.runs[] | select(.conclusion == "success")] | length),
  failed: ([.runs[] | select(.conclusion == "failure")] | length)
}]' /tmp/pr_ci/*.json > /tmp/nest_ci_all.json
```

**Why "longest job," not "wall-clock from first to last"**: GitHub returns ALL check runs ever associated with a commit, including reruns days later. Using `max(completed) - min(started)` blows up to weeks. The longest single run captures what actually held up merge.

### Step 4 — Compute stats with jq

Use `assets/compute-stats.jq` (see this skill's directory). It produces six JSON files consumed by the dashboard:
- `dashboard_data.json` — KPIs, by_area, by_state, top_reviewers/authors, by_day
- `timing.json` — cycle-time percentiles + distributions + slowest merges + by-author TTM
- `areas.json` — area×engineer matrix and per-area engineer rollups
- `slowest.json` — top 10 slowest merged PRs with author
- `iteration.json` — comments/commits/size distributions and most-iterated tables
- `pr_index.json` — flat per-PR index used by the click-drilldown modal

```bash
SKILL_DIR=$(dirname "$0")  # adjust to where you cloned the skill
jq -f "$SKILL_DIR/assets/compute-stats.jq" /tmp/nest_all.json > /tmp/stats_bundle.json
# split via jq into the six output files (see assets/split-bundle.sh)
```

### Step 5 — Generate the Findings section (agent-authored)

After the stats are computed, **read them and write a Findings & recommendations HTML block** that gets injected at the end of the dashboard. This section turns the dashboard from "raw data" into a leadership-ready narrative.

**What goes in it:**
- 5–8 findings, each grounded in a specific number from the dashboard (median TTM, no-human-reviewer count, top-author concentration, area medians, etc.)
- A "Process changes" recommendations table (3–5 rows, ranked gold/silver/bronze)
- A "Dashboard improvements" table (3–9 rows, ranked)
- A "Pick one" callout naming the single highest-leverage process move and the single highest-leverage dashboard move

**Reference structure:** `assets/findings-example.html` — copy the markup shape (CSS classes, table layout, medal pill ranks) but **regenerate every value from the actual data**. Numbers, names, area observations, and recommendations are all window-specific.

**What good findings look like:**
- ✅ "Median TTM is 5h but mean is 48h — a 9× ratio. The team isn't slow; it has a long tail." (specific numbers, names the lever)
- ✅ "dt-globelaxy owns 28/39 pedigree PRs (72%) — bus factor." (specific name, specific count, names the risk)
- ❌ "The team should communicate more." (no number, no lever, generic)
- ❌ "Consider improving cycle time." (no specific finding to act on)

**Tone:** editorial, direct, opinionated. The reader should walk away with 2-3 things they can do this week. No hedging. Use the `<em>` tag for the "lever" sentence in each finding.

Write the rendered HTML to `/tmp/findings.html` for substitution in Step 6.

### Step 6 — Render the dashboard HTML

Use `assets/dashboard-template.html`. It has seven placeholders. Substitute via Python (NOT shell `sed` — JSON contains characters that break sed):

```python
import os
out = '~/Desktop/nest-pr-analysis/index.html'
tpl = open('assets/dashboard-template.html').read()
for ph, path in [
    ('__DATA__',     '/tmp/dashboard_data.json'),
    ('__TIMING__',   '/tmp/timing.json'),
    ('__AREAS__',    '/tmp/areas.json'),
    ('__SLOW__',     '/tmp/slowest.json'),
    ('__ITER__',     '/tmp/iteration.json'),
    ('__PRIDX__',    '/tmp/pr_index.json'),
    ('__FINDINGS__', '/tmp/findings.html'),  # agent-authored, see Step 5
]:
    tpl = tpl.replace(ph, open(path).read())
open(os.path.expanduser(out),'w').write(tpl)
```

If you skip the Findings step, set `__FINDINGS__` to an empty string — the dashboard still works, it just ends after the volume section.

### Step 7 — Open locally and offer S3 upload

```bash
open ~/Desktop/nest-pr-analysis/index.html
```

Then ask: *"Upload to the team docs site?"* If yes, invoke the **`nest-summary-html`** skill's S3-upload step. The dashboard is already self-contained (Chart.js via CDN, no other assets), so it works directly.

Filename convention: `nest-pr-analysis-YYYY-MM-to-MM.html` (e.g. `nest-pr-analysis-2026-03-to-05.html`).

## Domain-Specific Area Classification

Title text is the only reliable area signal without per-PR file paths (which are too slow to fetch in bulk). The Nest title convention is `feat(NES-XXXX): description` — scopes are ticket IDs, **not** areas, so route on the description text.

Area buckets, in priority order (more specific first), are encoded in `assets/compute-stats.jq`. The Nest-specific clinical-genomics buckets are critical:

| Bucket | Title keywords |
|---|---|
| `release/merge` | `release`, `patch`, `merge stg`, `merge release`, `release candidate`, `2.X.X.X`, `backport`, `npm package update` |
| `care-plan` | `care plan`, `care research`, `care step`, `evidence to care` |
| `clinical-ai` | `ai assistant`, `chatbot`, `llm`, `ai summary`, `clinical ai` |
| `clinical-results` | `clinvar`, `gene findings`, `genepal`, `results overview`, `variant`, `ambry` |
| `pedigree` | `pedigree`, `relative`, `relationship`, `adopted`, `family history/sharing/size`, `proband` |
| `cancer-risk-assessment` | `cra`, `breast density`, `cancer subtype/risk`, `kidney`, `renal`, `sarcoma`, `tyrer-cuzick` |
| `assessments/forms` | `assessment`, `peds`, `inheritance field`, `insurance`, `dob`, `date mask` |
| `ehr-integration` | `athena`, `advancedmd`, `ecw`, `smart on fhir`, `fhir`, `epic`, `practitioner` |
| `lab-orders` | `myome`, `myriad`, `order` |
| `stories/questionnaires` | `story`, `questionnaire`, `narration`, `storyplayer`, `learn page`, `article drawer` |
| `consents` | `consent` |
| `patient-todos` | `todo`, `magic link` |
| `yoda(frontend)` | `yoda` |
| `patient-navigator` | `patient navigator`, `navigator` |
| `workflows/hooks` | `workflow`, `hook` |
| `auth/security` | `auth`, `login`, `cognito`, `frontegg`, `sign in/up`, `guard`, `redirect`, `launch flow` |
| `infra/ci` | `terraform`, `infra`, `deploy`, `github action`, `docker`, `nx`, `ci`, `cypress`, `jenkins`, `codespace` |

**Adding a new bucket** — extend the area function in `compute-stats.jq` and update both the heuristics table above and the dashboard template's color palette if needed. Order matters: put the more specific match earlier. After changing buckets, the percentage of PRs landing in `other` is the quality metric — aim for **<15%**.

## Bot Reviewer Filter

These accounts get added as reviewers automatically and should be filtered out of human-reviewer stats:

```
^(cursor|copilot|app/|dependabot|blacksmith|github-actions|eng$)
```

In the Nest repo, **`cursor`** appears as a reviewer on ~92% of PRs. Counting it in human-review stats produces meaningless data.

## KPIs You Should Always Surface

| KPI | Why it matters |
|---|---|
| Total PRs · merge rate · open count | Baseline throughput |
| **Median time-to-first-human-review** | Team responsiveness |
| **Median time-to-merge** + p90 in days | End-to-end cycle time |
| **Approval → merge** | CI/queue cost (often 0.3–2h, but tail is signaled by p90) |
| **PRs with no human reviewer** | Quality-gate signal |
| **Median total comments** | Iteration intensity proxy |
| **PR size distribution** | XL+ percentage correlates strongly with slow-merge tail |

## Client-Side Recompute (Window Selector)

The dashboard ships with a window selector that re-derives every metric from the filtered PR subset **without re-running the pipeline**. This is enabled by the `pr_index.json` carrying enough per-PR fields to reconstruct all aggregations:

| Field | Purpose |
|---|---|
| `c` (createdAt) | Window filter; daily-volume "Ready" / "Drafts" series |
| `m` (mergedAt) | Daily-volume "Merged" series; merge state |
| **`dr`** (isDraft) | Splits the daily-volume chart into Ready vs. Drafts series |
| **`ci`** (minutes, longest job) | CI duration percentiles + distribution histogram |
| **`cis`** (array of `{n,s}`) | Per-step CI durations — used to render "median by step" chart with Cursor-bot automation filtered out |
| `ttm` | Time-to-merge percentiles + distribution + slowest-merge ranking |
| **`ttfr`** | Time-to-first-review percentiles |
| **`ttfa`** | Time-to-first-approval percentiles + approval-to-merge derived as `ttm - ttfa` |
| `ad` / `de` | PR size buckets |
| `cmt` / `rc` / `co` / `cf` | Comment / commit / changed-files distributions |
| `r` (human reviewers) | Reviewer leaderboard, no-human-reviewer count |
| `a` (author) | Author leaderboard, area×engineer attribution |
| `ar` (area) | Area-of-work breakdown |

**Critical:** if you change `compute-stats.jq` to drop any of these fields (especially `ttfr`/`ttfa`), the window selector degrades silently — percentiles will read `null` for filtered windows. Keep them.

The recompute mirrors the jq formulas exactly (same percentile indexing, same bucket cutoffs, same sort orders). The "All captured" view from the selector is a parity check — it should produce identical numbers to the pre-baked stats.

## Common Mistakes

| Mistake | Fix |
|---|---|
| `gh pr list --json comments,commits` for the whole window | Use REST per-PR (Step 3) — GraphQL node-limit will 502 |
| Counting `cursor`/`copilot`/`eng` as human reviewers | Filter via the bot regex above |
| Treating `feat(NES-XXXX)` scope as the area | Scopes are ticket IDs — route on the description text after the colon |
| Reporting mean cycle time | Always p50/p75/p90 — a single 50-day-old PR ruins the mean |
| `sed`-substituting JSON into HTML template | JSON contains `&`, `/`, `\n` — use Python `str.replace` |
| Generic web buckets ("frontend", "backend") for a clinical product | Use the domain buckets (pedigree, clinical-results, EHR-integration) — they cut "other" from ~70% to <15% |
| Forgetting to dedupe across date chunks | `jq -s 'add | unique_by(.number)'` — overlapping search windows are common |
| Including `cursor` PRs in the "no reviewer" count | The `prs_with_no_human_reviewer` metric is the meaningful one |
| Dropping `ttfr` / `ttfa` from `pr_index` | Window selector silently degrades — keep them in `compute-stats.jq` |
| Treating draft PRs as a "state" | Draft is a separate boolean (`isDraft`) — drafts have `state=OPEN/CLOSED/MERGED` like any PR. Filter via `.dr` in JS, not by state. |
| Counting "PRs created" without distinguishing drafts | Mixes WIP with review-ready throughput. The dashboard splits the daily chart into Ready / Merged / Drafts so the team can see both signals separately. |
| Skipping the Findings section | The raw dashboard is a data dump; the Findings section is what makes it leadership-readable. Don't skip — it's where the value lands. |
| Pasting the example findings verbatim | `findings-example.html` shows the markup shape only. Numbers, names, areas, and recommendations must come from the actual data window. |
| Hedging language in findings ("might", "could perhaps", "consider") | The findings should be opinionated and direct. If the data shows pedigree is single-owner at 72%, name it as a bus-factor risk — don't soften. Hedging makes the document forgettable. |
| Including release/RC PRs in cycle-time / size / churn metrics | RC PRs are branch merges with hundreds of commits and seconds-to-merge — they distort every aggregation. The dashboard filters `release/merge` everywhere; preserve this. |
| Using `max(completed_at) - min(started_at)` for CI duration | GitHub returns ALL check runs ever associated with a commit including reruns days later. The first-to-last span balloons to weeks. Use the **longest single check-run duration** as the gating CI time. |
| Filtering Cursor automation out of CI step charts | Show them with a muted gray + 🤖 prefix so the reader can compare bot-runtime against gating-CI runtime. Hiding them entirely loses the "the bot is taking longer than my actual CI" insight. |
| Counting product team members in review-load metrics | `caitlinbinder`, `emiliesimmons`, `lauraehayward16` are product, not engineering. Filter them out via `PRODUCT_TEAM`. They remain visible in the reviewer table when they did review (with a "product" tag). |
| Hardcoded chart colors that don't update on theme switch | Read CSS tokens at chart-build time (`getComputedStyle(...).--accent`) and rebuild on theme change via `window.__rebuildCharts` |
| `sed` to inject JSON into the template | Use Python `str.replace` — JSON contains `\\n`, `&`, slashes that break sed |

## Dependencies

- **GitHub CLI** (`gh`) — auth must be live (`gh auth status`)
- **jq** — for stat aggregation
- **python3** — for HTML template substitution
- **AWS CLI** with `tst-account-administrator-role` profile (only if uploading to S3)

## Brand & UI

The dashboard uses the same design system as `nest-summary-html` (the long-form doc skill). Don't restyle it — the brand is locked:

- **Typography** — `Instrument Serif` for H1 (with the canonical orange→purple gradient text), serif for KPI numbers and percentile values; `-apple-system` sans for body and table content
- **Themes** — 5 (`nest`/`slate`/`forest`/`paper`/`dusk`) × 3 modes (`light`/`dark`/`system`) × 3 widths (`narrow`/`wide`/`full`), persisted to `localStorage` under the `nest-doc-*` keys (shared with long-form docs)
- **Tokens** — `--accent`, `--accent-2`, `--accent-3`, `--rose`, `--ink`, `--bg`, `--border`, `--hover`, `--card-bg` derived via `color-mix(in oklch, ...)` so all surfaces re-skin together when the theme changes
- **Charts** — Chart.js bars/lines/donuts read CSS tokens at build time via `getComputedStyle(...)` and **fully rebuild on theme change** via `window.__rebuildCharts()`. Don't hardcode hex values for chart colors.
- **Modal** — backdrop blur, Instrument Serif title, eyebrow above title, state pills colored from theme tokens

When extending the UI, follow the `nest-summary-html` template patterns rather than introducing new design primitives. The two skills share enough that a reader of either feels they're in the same brand system.

## Asset Files (in this skill's directory)

- `assets/dashboard-template.html` — Brand-styled Chart.js dashboard with window selector, sidebar TOC, click-drilldown modal, client-side recompute, and a `__FINDINGS__` slot for the agent-authored section
- `assets/compute-stats.jq` — single jq script that emits the full stats bundle (including `ttfr`/`ttfa` in `pr_index` for client-side recompute)
- `assets/split-bundle.sh` — splits the bundle into the six per-section JSON files
- `assets/findings-example.html` — markup reference for the Findings section. Copy the structure, regenerate every value from the actual data.

The agent should read these files directly when running the workflow rather than re-deriving the jq logic.
