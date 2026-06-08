---
name: nest-linear-beta
description: Work with Linear issues AND documents via CLI - use whenever the user asks about Linear issues (create/update/comment/delete/status) or Linear documents/articles (create/read/list/search prose docs)
version: 0.1.0-beta
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
  printf '{"v":2,"skill":"nest-linear-beta","version":"0.1.0-beta","agent":"%s","ts":"%s","branch":"%s"}\n' \
    "$_AGENT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_BRANCH" \
    >> ~/.nest/skill-analytics/skill-usage.jsonl 2>/dev/null || true
} 2>/dev/null || true
```


# Linear Issue Management

**Use this skill whenever the user mentions Linear or asks to work with issues.**

Lightweight CLI to interact with Linear's issue tracking system.

## Setup

Credentials are stored in `~/.config/nest-skills/linear.env`. If the user explicitly asks to set up Linear, or if any command fails with `LINEAR_API_KEY not configured`:

1. Check if `~/.config/nest-skills/linear.env` exists
2. If missing, ask the user for their Linear API key (from https://linear.app/settings/api > Personal API keys)
3. Save the key:
   ```bash
   mkdir -p ~/.config/nest-skills
   echo "LINEAR_API_KEY=<key>" > ~/.config/nest-skills/linear.env
   ```
4. Retry the original request

## Nest Genomics Workspace

### Teams

| Key | Name | ID | Notes |
|-----|------|----|-------|
| **NES** | Nest Genomics | `96fa5642-afc0-4d12-a7c6-f0b117b415e4` | Main engineering team. Has triage, cycles, t-shirt estimation. Default for most issues. |
| **CON** | Content | `75fcc429-e29d-49da-8e40-d7e448c89def` | Content team (care templates, manuscripts, social media) |
| **AM** | Account Management | `cbfa24f3-c7ea-45b6-a14f-7762a5f88f03` | Account onboarding and management |
| **CRM** | Nest CRM | `fb5ddbb1-3d70-40d8-8572-675e85ccd1f2` | Sales pipeline (Lead → Qualified → Contracting → Live) |
| **SUP** | Support | `5ef4fa6d-48de-4b21-b7a6-5f6f398afa32` | Customer support tickets |

**Default:** When not specified, assume `NES` team for engineering work.

### NES Workflow States (in order)

| Status | Type | Use when |
|--------|------|----------|
| Triage | triage | New issues awaiting prioritization |
| Backlog | backlog | Prioritized but not scheduled |
| Reqts & Design | unstarted | Requirements gathering and design phase |
| Tech Approach & Size | unstarted | Technical scoping and estimation |
| Todo | unstarted | Ready to be picked up |
| In Progress | started | Actively being worked on |
| In Review | started | Code review / PR open |
| Code Complete | started | Code merged, awaiting testing |
| Acceptance Testing on TST | started | QA testing on TST environment |
| Acceptance Testing on STG | started | QA testing on STG environment |
| Post Release Urgent | started | Released, needs urgent follow-up |
| Post Release Non-Urgent | started | Released, non-urgent follow-up |
| Done | completed | Fully complete |
| Canceled | canceled | Won't do |

### Key Labels

| Category | Labels | Use when |
|----------|--------|----------|
| **Type** | `Bug` | Bug reports (auto-applied by Bug template) |
| **Type** | `Tech debt` | Refactoring, cleanup |
| **Type** | `Story`, `Story change` | Feature stories, story modifications |
| **Type** | `Delight` | UX improvements |
| **Area** | `Clinical`, `Rule Engines`, `AI` | Domain area |
| **Area** | `Internal tooling / Automation`, `Myome` | Product area |
| **Sub-owner** | `!!Sub-owner` > person name (e.g., `CHRIS`, `ALKIS`) | Secondary ownership tracking |
| **Release** | `!Releases` > version (e.g., `2.15.0`) | Release tagging |
| **Accounts** | `Accounts` > account name | Account-specific work |

### Templates

Use templates when creating issues to match Nest conventions.

**New Issue (default for NES team, ID: `5ba992ce-ce03-4ee3-9a27-9eaa1bb6ece9`):**
```markdown
As a [type of user] I want [something] so that I can [something]

[Additional background if needed]

### Acceptance Criteria
[Document requirements for front end, back end, analytics, etc]

### Technical Approach
[Required for tickets where AC is written by PM]

### Testing
[Optional testing instructions. Specify if STG required instead of TST.]

### Retool
[If Retool updates needed, document specific needs including design]

### UI/UX/Design
[Add relevant design requirements and related design mocks or magic patterns link]

### Post-release tasks
- [ ] [Add PRD tasks related to this issue]
```
**Omit empty sections** — a simple fix may only need user story + AC.

**Bug (NES team, ID: `60be3f29-cf58-479b-a04b-cf611e74ad57`):**
Title format: `BUG: <description>`. Auto-labels with `Bug`. Goes to Triage.
```markdown
<description of bug>

### Expected behavior
- TODO

### Steps to Reproduce
TODO

### Screenshots, video, etc
TODO
```

**Tech Design (NES team, ID: `22d47fa3-fc08-472d-87a3-ca37eb936499`):**
Title format: `<Feature> Tech Design`. Goes to Triage.
```markdown
Expected due date: XXXX-XX-XX
- [ ] Alignment on Requirements, Goals, and Scope
- [ ] Write up the tech doc
- [ ] Get it reviewed
- [ ] Iterate on Feedback
- [ ] Linear project and issues

## In Detail:
### Understand Requirements and Agree on Goals
[Clarify the problem statement and goals with the product team and/or stakeholders.]

### Technical Proposal (Timebox: 1-2 Days)
[Follow the Slite template: https://nestgenomics.slite.com/app/docs/BHYbPUc7fLnWxO/Technical-Design-Document]

### Request Review
[Ask teammates to review offline and schedule time to present. Keep questions in Slite comments or Q&A section.]

### Iterate on the Review (up to 2 Days)
[Address all feedback until proposal is clear.]

### Document, Commit, and Create Tickets/Tasks
[Output: clear problem description, technical deliverables, design doc, Linear Project with issues.]
```

**Root Cause Analysis (NES team, ID: `cf36d1df-e4ea-44ec-ab92-29190e70252c`):**
Title format: `RCA for BUG: NES-ABCD`. For post-mortem analysis of bugs.

**Other templates:** `Athena Integration` (AM/Org), `Epic Integration` (Org), `Lab Integration` (Org), `Onboard {clinicName}` (Org), `Release readiness` (Org), `CRM template` (CRM), `New Care Template Ticket` (CON).

### Team Members

| Name | Handle | ID |
|------|--------|----|
| Guy Snir | guy | `dcb4ad1c-9814-4fb7-be5d-f375160d08e8` |
| Brian Cerceo | brian | `396a2d3d-7cc5-4029-873f-b214b3541d63` |
| Alkis Sellis | alkis | `9dedb989-d33c-4409-8f6d-db3380fd95ab` |
| Laura Hayward | laura | `80cff5f6-5126-41e7-bb76-77756a08639b` |
| Emilie Simmons | emilie | `75c76290-a71b-4f12-99d3-644f849b2281` |
| Costas Marinos | costas | `76044e11-71dc-43a9-aaf4-44480f2a4ebd` |
| Dmitry Trifonov | dmitry | `c3bea5b6-cbf8-448b-8dcb-004d8d9ea884` |
| Chris Gatzonis | chris | `dee8aef7-26c5-4c03-bea0-1ff7df2c1dd3` |
| Mary Ann Sundermeyer | maryann | `3664aa93-c613-445f-96c2-f5477fc59c88` |
| Moran Snir | moran | `8a9c42a1-dbab-411a-91f8-967776412ffa` |
| Caitlin | caitlin | `37bc753b-300b-48f2-a536-a492ae7d6bb6` |
| Jordan | jordan | `f1ba83f4-dd6c-40f9-9d87-e6a77e52b91b` |

---

## Command Pattern

```bash
./linear <resource> <action> [arguments] [options]
```

Resources: `issue`, `document`, `cycle`, `comment`, `user`, `team`, `project`, `template`, `label`, `status`, `inbox`, `favorites`

## Commands

### List Users
```bash
./linear user list
```
Returns: `#<user-id>	<name>	<email>`

### List Teams
```bash
./linear team list
```
Returns: `#<team-id>	<name>	<key>`

### List Projects
```bash
./linear project list [--active] [--no-backlog] [--limit N]
```
Groups projects by the **team's color convention** — `project.color`, the sidebar hexagon accent, which the team uses as the *real* status (it does NOT track Linear's `status` field):

| Icon | `project.color` | Meaning |
|---|---|---|
| 🟢 ACTIVE | `#4cb782` (green) | being worked on now |
| 🟡 RAMPING | `#f2c94c` (yellow) | split by progress → **↘ rolling off** (≥50%, winding down) vs **↗ ramping up / planning** (<50%, spinning up) |
| ⚪ BACKLOG | `#bec2c8` (gray, default) / other | dormant |

Each row also shows Linear's `status` name, `health` (🟢 on-track / 🟡 at-risk / 🔴 off-track), progress %, and lead — so you can spot **drift** (e.g. a 🟢 active project still sitting in Linear status "Backlog").

- `--active` → only the green tier (what's actually in flight, ~5 projects).
- `--no-backlog` → active + ramping (hides the ~84 dormant).
- `--ramp-threshold N` → progress % cutoff between rolling-off and ramping-up (default 50).
- `--json` → raw fields incl. `color`, `status`, `health`, `progress`.

> The yellow tier carries no direction in the API (both ways are `#f2c94c`); the rolling-off vs ramping-up split is derived from `progress` (≥ threshold = rolling off). The exact Projects-view row order isn't reproducible — Linear only exposes global `sortOrder`/`prioritySortOrder`, which don't match a saved view.

### List Issues
```bash
./linear issue list [options]
```
**Options:**
- `--team <id>` - Filter by team ID
- `--assignee <id>` - Filter by user ID
- `--status <name>` - Filter by status name (case-sensitive)
- `--limit <n>` - Limit results (default: 50)

Returns: `#<identifier>	<title>	<status>	<assignee>`

**Examples:**
```bash
./linear issue list --team 96fa5642-afc0-4d12-a7c6-f0b117b415e4 --limit 10
./linear issue list --status "In Progress" --limit 20
```

### View Issue
```bash
./linear issue view <id-or-key>
```
**Arguments:**
- `<id-or-key>` - Issue identifier (e.g., `NES-123`) or UUID

Returns full issue details including title, status, assignee, team, priority, labels, dates, description, attachments, and comments.

### Create Issue
```bash
./linear issue create <title> [options]
```
**Arguments:**
- `<title>` - Issue title (multi-word titles auto-combined)

**Options:**
- `--team <id>` - Team ID (required)
- `--body <text>` - Issue description (short text)
- `--body-file <file>` - Read description from file (use `"-"` for stdin)
- `--assignee <id>` - User ID (use `"@me"` for yourself)
- `--priority <n>` - Priority (0=None, 1=Urgent, 2=High, 3=Medium, 4=Low)
- `--status <name>` - Initial status
- `--label <name>` - Label(s) - can repeat or comma-separate
- `--parent <id>` - Parent issue ID (for sub-issues)

**Nest Examples:**
```bash
# Create a bug on NES team (use Bug template format)
./linear issue create "BUG: Login fails on Safari" --team 96fa5642-afc0-4d12-a7c6-f0b117b415e4 --label Bug --priority 2

# Create a feature on NES team
cat feature-desc.md | ./linear issue create "Add patient timeline view" --team 96fa5642-afc0-4d12-a7c6-f0b117b415e4 --body-file - --assignee @me

# Create content ticket
./linear issue create "Gene-Syndrome: BRCA1" --team 75fcc429-e29d-49da-8e40-d7e448c89def --priority 2
```

### Add Comment
```bash
./linear issue comment <id-or-key> <text>
```
Multi-word text auto-combined. No quotes needed.

### Update Issue
```bash
./linear issue update <id-or-key> [options]
```
**Options:**
- `--status <name>` - Update status
- `--assignee <id>` - Update assignee (use `"@me"` for yourself)
- `--priority <n>` - Update priority
- `--title <text>` - Update title
- `--body <text>` - Update description (short text)
- `--body-file <file>` - Read description from file (use `"-"` for stdin)
- `--label <name>` - Add label(s)
- `--parent <id>` - Set parent issue

Can update multiple fields in one command.

**Examples:**
```bash
./linear issue update NES-123 --status "In Progress" --assignee @me
./linear issue update NES-456 --status "Code Complete" --label "2.15.0"
```

### Delete Issue
```bash
./linear issue delete <id-or-key>
```
Soft delete (moves to trash, recoverable).

### List/Download Images
```bash
./linear issue images <id-or-key> [options]
```
List or download inline images from an issue's description (markdown `![](url)` images).

**Options:**
- `--download` - Download images to disk
- `--output <dir>` - Directory to save images (default: current directory)

**Examples:**
```bash
./linear issue images NES-123
./linear issue images NES-123 --download --output /tmp/images
```

### Upload File / Attachment
```bash
./linear issue upload <id-or-key> <file> [options]
```
Uploads a file to Linear (via signed S3 URL), creates a sidebar attachment record, and optionally posts a comment with the file embedded inline. Use this for screenshots, videos, PDFs, HAR files, or any other artifact you want attached to an issue.

**Options:**
- `--comment <text>` - Also post a comment; the file is embedded at the end via `![filename](assetUrl)` markdown so Linear's renderer inlines images and videos
- `--comment-file <file>` - Read comment body from file (use `"-"` for stdin) — useful for piping a markdown report
- `--title <text>` - Title for the sidebar attachment (default: filename)
- `--no-attachment` - Skip creating a sidebar attachment record (still uploads + can comment)
- `--content-type <mime>` - Override auto-detected content type
- `--json` - Output `{ asset_url, comment_url, attachment_id, ... }` for piping into other tools

**Output:** prints the asset URL, the Linear comment deep-link (when `--comment` is used), and the attachment ID. With `--json`, returns those as a structured object — use `comment_url` to link from a GitHub PR comment back to the Linear comment that hosts the embedded media.

**Examples:**
```bash
# Attach a video walkthrough and embed it in a comment with a markdown report
./linear issue upload NES-123 ./session.webm \
  --comment-file ./report.md \
  --title "AC validation walkthrough"

# Quick screenshot attachment, no comment
./linear issue upload NES-123 ./screenshot.png --title "Repro screenshot"

# Pipe a generated report from stdin
cat report.md | ./linear issue upload NES-123 ./session.webm --comment-file - --json
```

### Create Issue Relation
```bash
./linear issue relate <id-or-key> <related-id-or-key> [options]
```
**Options:**
- `--type <type>` - Relation type: `blocks`, `duplicate`, `related` (default: `blocks`)

**Examples:**
```bash
# NES-456 blocks NES-123 (NES-123 is blocked by NES-456)
./linear issue relate NES-123 NES-456 --type blocks

# Mark as duplicate
./linear issue relate NES-123 NES-456 --type duplicate

# Create a generic relation
./linear issue relate NES-123 NES-456 --type related
```

### List Workflow States
```bash
./linear team states [team-key]
```
Lists all workflow states grouped by type (triage, backlog, unstarted, started, completed, canceled). Optionally filter by team key.

**Examples:**
```bash
./linear team states          # All teams
./linear team states NES      # NES team only
./linear team states NES --json
```

### List Labels
```bash
./linear team labels [team-key]
./linear label list [--group]
```
List labels for a specific team or all workspace labels. Use `--group` to group by parent label.

**Examples:**
```bash
./linear team labels NES         # Labels available to NES team
./linear label list              # All workspace labels
./linear label list --group      # Grouped by parent (!!Sub-owner, !Releases, etc.)
./linear label list --json
```

### List Templates
```bash
./linear template list [--team KEY]
```
Lists all issue templates. Optionally filter by team key.

**Examples:**
```bash
./linear template list             # All templates
./linear template list --team NES  # NES templates only
```

### View Template
```bash
./linear template view <id>
```
View a template's content including title format, labels, state, priority, and rendered description.

**Examples:**
```bash
./linear template view 60be3f29-cf58-479b-a04b-cf611e74ad57        # Bug template
./linear template view 5ba992ce-ce03-4ee3-9a27-9eaa1bb6ece9        # New Issue template
./linear template view 60be3f29-cf58-479b-a04b-cf611e74ad57 --json # Raw JSON with parsed templateData
```

## Utilities (beta)

```bash
./linear status                 # current user + live API rate-limit headroom
./linear inbox [--unread] [--limit N]   # your notification feed (• = unread)
./linear favorites [--limit N]  # pinned issues/projects/views
```
- `status` resolves `viewer` (who am I) and `rateLimitStatus` (requests + complexity remaining this window, with reset time) — a fast sanity check before bulk operations.
- `inbox` lists notifications using the `Notification` interface's common fields; `--unread` filters to `readAt == null`. Header shows `notificationsUnreadCount`.

## Issue Search (beta)

```bash
./linear issue search <query> [--semantic] [--team KEY] [--limit N]
```
- **Default** = text search (`searchIssues`) across titles/descriptions; reports `totalCount`.
- **`--semantic`** = Linear's AI embedding search (`semanticSearch`) — natural-language queries that span **issues, projects, documents, and initiatives** in one result set.

```bash
./linear issue search "clinvar link" --team NES
./linear issue search "wrong variant link mismatch" --semantic
```

## Cycles (beta)

```bash
./linear cycle list [team-key]
./linear cycle view <id-or-team-key>
```
- `list` shows cycles tagged `[active|future|past]` with date range + progress.
- `view` prints **per-assignee throughput** (done/total issues + points) for a cycle. Pass a **cycle UUID**, or a **team key** (`NES`) to use that team's *active* cycle — the fast way to see who's shipping this cycle.

```bash
./linear cycle view NES        # active NES cycle, throughput per person
```

## Comments & Reactions (beta)

```bash
./linear comment list <issue-id-or-key>     # lists comments WITH their #ids
./linear comment react <comment-id> <emoji> # emoji = shortcode: +1, tada, eyes, heart
```
Get a comment-id from `comment list`, then react. Reactions are removable in the Linear UI (or via `reactionDelete`).

## Documents (beta)

Linear **documents** are prose docs (specs, RFCs, meeting notes) stored alongside issues. The body is plain **markdown** in the `content` field. This is the capability that distinguishes `nest-linear-beta` from `nest-linear`.

### List Documents
```bash
./linear document list [--limit N]
```
Returns: `[<updated-date>] <title>	<project|—>	#<doc-id>` (most-recently-updated first).

### View Document
```bash
./linear document view <id-or-title>
```
Pass a **UUID** for a direct lookup, or an **exact title** (resolved via `documents(filter:{title:{eq}})`). Prints metadata + the full markdown body. **Note:** a document URL ends in a short *slug*, NOT the UUID — you can't pass the URL/slug; use the UUID or exact title.

### Search Documents
```bash
./linear document search <term>
```
Full-text search across document bodies (`searchDocuments`). Returns up to 20 matches.

### Create Document
```bash
./linear document create <title> <anchor> [--content <md> | --content-file <file>]
```
**Anchor — exactly ONE is REQUIRED** (Linear's validator rejects zero or multiple):
- `--team <id|key>` (team key like `NES` is auto-resolved to its UUID)
- `--project <id>` · `--issue <id-or-key>` · `--initiative <id>` · `--cycle <id>` · `--release <id>`

**Body:** `--content "<markdown>"` or `--content-file <file>` (use `"-"` for stdin).

**Examples:**
```bash
# Create a spec doc on the NES team from a markdown file
./linear document create "Spec: patient timeline" --team NES --content-file spec.md

# Attach a doc to an issue, body from stdin
echo "# Notes" | ./linear document create "Design notes" --issue NES-123 --content-file -

# Anchor to a project
./linear document create "Kickoff" --project <project-uuid> --content "## Agenda\n- ..."
```

> **Gotchas (learned the hard way):** the schema types every anchor as optional `String`, but the API enforces *exactly one* at validation time. `icon` is intentionally unsupported — Linear rejects emoji (it wants a named icon from its own set), so this CLI omits it.

## Important Notes

- Issue identifiers are case-insensitive (`NES-123` = `nes-123`)
- Status names are case-sensitive ("In Progress" not "in progress")
- User/team IDs are UUIDs (get from list commands or reference tables above)
- Issue keys format: `<TEAM_KEY>-<NUMBER>` (e.g., NES-123, CON-45, AM-78)
- All commands support `--json` flag for machine-readable output
- Use `--help` on any command for details
- When creating NES issues, format the description body using the appropriate template (New Issue for features, Bug for bugs)
