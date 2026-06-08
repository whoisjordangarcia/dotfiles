#!/usr/bin/env node
import { LinearClient } from "@linear/sdk"
import { fileURLToPath } from "url"
import { dirname, join, basename, extname } from "path"
import { readFileSync, writeFileSync, mkdirSync, existsSync, statSync } from "fs"
import fetch from "node-fetch"
// Get the directory of the linear executable (parent of scripts/)
const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)
const linearDir = join(__dirname, "..")
function parseArgs(argv) {
  const args = []
  const flags = {}
  let resource = ""
  let action = ""
  for (let i = 2; i < argv.length; i++) {
    const arg = argv[i]
    if (arg.startsWith("--")) {
      const key = arg.slice(2)
      const nextArg = argv[i + 1]
      if (nextArg && !nextArg.startsWith("-")) {
        // Support multiple values for the same flag (e.g., --label foo --label bar)
        if (flags[key]) {
          // Convert to array if not already
          if (!Array.isArray(flags[key])) {
            flags[key] = [flags[key]]
          }
          flags[key].push(nextArg)
        } else {
          flags[key] = nextArg
        }
        i++
      } else {
        flags[key] = true
      }
    } else if (arg.startsWith("-")) {
      flags[arg.slice(1)] = true
    } else if (!resource) {
      resource = arg
    } else if (!action) {
      action = arg
    } else {
      args.push(arg)
    }
  }
  return { resource, action, args, flags }
}
function showHelp() {
  console.log(`linear-cli - CLI for working with Linear

Usage: linear-cli <resource> <action> [arguments] [options]

Resources:
  issue      Work with issues (incl. text/semantic search)
  document   Work with documents (create/read/list/search)
  cycle      Work with cycles (list, per-person throughput)
  comment    List comments, add emoji reactions
  user       Work with users
  team       Work with teams
  project    Work with projects (status + health colors)
  template   Work with issue templates
  label      Work with labels
  status     Current user + API rate-limit headroom
  inbox      Your notifications (--unread to filter)
  favorites  Your pinned issues/projects/views

Global Options:
  -h, --help    Show help
  --json        Output raw JSON

Run 'linear-cli <resource> --help' for resource-specific help
Run 'linear-cli <resource> <action> --help' for action-specific help

Examples:
  linear-cli issue list
  linear-cli issue view ENG-123
  linear-cli issue create "Fix bug" --team <team-id>
  linear-cli user list`)
}
function showUserHelp() {
  console.log(`Usage: linear-cli user <action>

Actions:
  list    List all users

Options:
  --json       Output raw JSON
  -h, --help   Show help

Examples:
  linear-cli user list
  linear-cli user list --json`)
}
function showTeamHelp() {
  console.log(`Usage: linear-cli team <action> [arguments] [options]

Actions:
  list                    List all teams
  states [team-key]       List workflow states for a team
  labels [team-key]       List labels for a team

Options:
  --json       Output raw JSON
  -h, --help   Show help

Examples:
  linear-cli team list
  linear-cli team states NES
  linear-cli team labels NES --json`)
}
function showTemplateHelp() {
  console.log(`Usage: linear-cli template <action> [arguments] [options]

Actions:
  list                    List all templates
  view <id>               View a template's content

Options:
  --team <key>   Filter templates by team key
  --json         Output raw JSON
  -h, --help     Show help

Examples:
  linear-cli template list
  linear-cli template list --team NES
  linear-cli template view <template-id>`)
}
function showLabelHelp() {
  console.log(`Usage: linear-cli label <action> [options]

Actions:
  list    List all labels

Options:
  --group        Group labels by parent
  --json         Output raw JSON
  -h, --help     Show help

Examples:
  linear-cli label list
  linear-cli label list --group
  linear-cli label list --json`)
}
function showProjectHelp() {
  console.log(`Usage: linear-cli project <action>

Actions:
  list    List all projects

Options:
  --json       Output raw JSON
  -h, --help   Show help

Examples:
  linear-cli project list
  linear-cli project list --json`)
}
function showDocumentHelp() {
  console.log(`Usage: linear-cli document <action> [arguments] [options]

Actions:
  list                      List documents (most-recently-updated first)
  view <id-or-title>        Show a document's markdown content
  search <term>             Full-text search documents
  create <title>            Create a new document

Anchoring (create): exactly ONE of the following is REQUIRED —
  --team <id|key>    --project <id>    --issue <id-or-key>
  --initiative <id>  --cycle <id>      --release <id>

Options:
  --content <text>        Document body as markdown
  --content-file <file>   Read body from file (use "-" for stdin)
  --limit <n>             Limit list results (default: 50)
  --json                  Output raw JSON
  -h, --help              Show help

Notes:
  - Document body is plain MARKDOWN (tables, headings, **bold** all render).
  - A document URL ends in a short slug, NOT the UUID; 'view' resolves a
    non-UUID argument by exact title match.
  - 'icon' is intentionally unsupported: Linear rejects emoji (it wants a
    named icon from its own set).

Examples:
  linear-cli document list
  linear-cli document list --limit 10 --json
  linear-cli document view "Locked literature, by publisher"
  linear-cli document view 36c3ce9b-1722-4b53-82e5-467602987817
  linear-cli document search "step function"
  linear-cli document create "Spec: X" --team NES --content-file spec.md
  echo "# Body" | linear-cli document create "Notes" --project <id> --content-file -`)
}
function showCycleHelp() {
  console.log(`Usage: linear-cli cycle <action> [arguments] [options]

Actions:
  list [team-key]           List cycles (optionally for one team)
  view <id-or-team-key>     Per-assignee throughput for a cycle.
                            Pass a cycle UUID, or a team key (NES) for its
                            ACTIVE cycle.

Options:
  --limit <n>   Limit list results (default: 20)
  --json        Output raw JSON
  -h, --help    Show help

Examples:
  linear-cli cycle list NES
  linear-cli cycle view NES            # active NES cycle, throughput per person
  linear-cli cycle view <cycle-uuid>`)
}
function showCommentHelp() {
  console.log(`Usage: linear-cli comment <action> [arguments] [options]

Actions:
  list <issue-id-or-key>          List an issue's comments WITH their #ids
  react <comment-id> <emoji>      Add an emoji reaction to a comment

Options:
  --json        Output raw JSON
  -h, --help    Show help

Notes:
  - 'react' takes an emoji shortcode name like "+1", "tada", "eyes", "heart".
  - Get a comment-id from 'comment list <issue>'.

Examples:
  linear-cli comment list NES-123
  linear-cli comment react <comment-uuid> +1
  linear-cli comment react <comment-uuid> tada`)
}
function showIssueHelp() {
  console.log(`Usage: linear-cli issue <action> [arguments] [options]

Actions:
  list                            List issues with filters
  search <query>                  Text search (add --semantic for AI search)
  view <id-or-key>                Get detailed information about an issue
  create <title>                  Create a new issue
  update <id-or-key>              Update an issue
  delete <id-or-key>              Delete an issue (moves to trash)
  comment <id-or-key> <text>      Add a comment to an issue
  relate <id> <related-id>        Create a relation between two issues
  images <id-or-key>              List or download inline images from description
  upload <id-or-key> <file>       Upload a file (attachment + optional comment)

Global Options:
  --json       Output raw JSON
  -h, --help   Show help

Run 'linear-cli issue <action> --help' for action-specific help`)
}
function showIssueListHelp() {
  console.log(`Usage: linear-cli issue list [options]

List issues with filters

Options:
  --team <id>       Filter by team ID
  --assignee <id>   Filter by assignee user ID
  --status <name>   Filter by status name
  --limit <n>       Limit results (default: 50)
  --json            Output raw JSON
  -h, --help        Show help

Examples:
  linear-cli issue list
  linear-cli issue list --team <team-id>
  linear-cli issue list --status "In Progress" --limit 10`)
}
function showIssueViewHelp() {
  console.log(`Usage: linear-cli issue view <id-or-key> [options]

Get detailed information about an issue

Arguments:
  id-or-key    Issue identifier (e.g., ENG-123 or full UUID)

Options:
  --json       Output raw JSON
  -h, --help   Show help

Examples:
  linear-cli issue view ENG-123
  linear-cli issue view <issue-uuid> --json`)
}
function showIssueCreateHelp() {
  console.log(`Usage: linear-cli issue create <title> [options]

Create a new issue

Arguments:
  title                 Issue title

Options:
  --team <id>           Team ID (required)
  --body <text>         Issue description (use --body-file for long text)
  --body-file <file>    Read description from file (use "-" for stdin)
  --assignee <id>       Assignee user ID (use "@me" for yourself)
  --label <name>        Label name(s) - can be specified multiple times or comma-separated
  --project <id>        Project ID to assign the issue to
  --parent <id>         Parent issue ID (for creating sub-issues)
  --priority <n>        Priority (0=None, 1=Urgent/P0, 2=High/P1, 3=Medium/P2, 4=Low/P3)
  --estimate <n>        Story point estimate
  --due-date <date>     Due date (YYYY-MM-DD format)
  --status <name>       Initial status (e.g. "Backlog", "Todo", "In Progress")
  --json                Output raw JSON
  -h, --help            Show help

Examples:
  linear-cli issue create "Fix bug" --team <team-id>
  linear-cli issue create "New feature" --team <team-id> --body "Details" --priority 2
  linear-cli issue create "Task" --team <team-id> --label bug --label p0
  echo "Long description" | linear-cli issue create "Title" --team <team-id> --body-file -
  linear-cli issue create "Sub-task" --team <team-id> --parent PROJ-123 --assignee @me`)
}
function showIssueUpdateHelp() {
  console.log(`Usage: linear-cli issue update <id-or-key> [options]

Update an issue

Arguments:
  id-or-key             Issue identifier (e.g., ENG-123 or full UUID)

Options:
  --status <name>       Update status
  --assignee <id>       Update assignee (use "@me" for yourself)
  --priority <n>        Update priority (0=None, 1=Urgent/P0, 2=High/P1, 3=Medium/P2, 4=Low/P3)
  --title <text>        Update title
  --body <text>         Update description
  --body-file <file>    Read description from file (use "-" for stdin)
  --label <name>        Add label(s) - can be specified multiple times or comma-separated
  --project <id>        Assign to project
  --parent <id>         Set parent issue (for creating sub-issues)
  --estimate <n>        Update story point estimate
  --due-date <date>     Set due date (YYYY-MM-DD format)
  --json                Output raw JSON
  -h, --help            Show help

Examples:
  linear-cli issue update ENG-123 --status "In Progress"
  linear-cli issue update ENG-123 --assignee @me --priority 1
  linear-cli issue update ENG-123 --label bug --label urgent`)
}
function showIssueDeleteHelp() {
  console.log(`Usage: linear-cli issue delete <id-or-key> [options]

Delete an issue (moves to trash)

Arguments:
  id-or-key    Issue identifier (e.g., ENG-123 or full UUID)

Options:
  --json       Output raw JSON
  -h, --help   Show help

Examples:
  linear-cli issue delete ENG-123
  linear-cli issue delete <issue-uuid>`)
}
function showIssueCommentHelp() {
  console.log(`Usage: linear-cli issue comment <id-or-key> <text> [options]

Add a comment to an issue

Arguments:
  id-or-key    Issue identifier (e.g., ENG-123 or full UUID)
  text         Comment text

Options:
  --json       Output raw JSON (comment details)
  -h, --help   Show help

Examples:
  linear-cli issue comment ENG-123 "This looks good"
  linear-cli issue comment ENG-123 "Fixed in PR #42" --json`)
}
function showIssueImagesHelp() {
  console.log(`Usage: linear-cli issue images <id-or-key> [options]

List or download inline images from an issue's description

Arguments:
  id-or-key          Issue identifier (e.g., ENG-123 or full UUID)

Options:
  --download         Download images to disk
  --output <dir>     Directory to save images (default: current directory)
  --json             Output raw JSON (image URLs and metadata)
  -h, --help         Show help

Examples:
  linear-cli issue images ENG-123
  linear-cli issue images ENG-123 --download
  linear-cli issue images ENG-123 --download --output /tmp/images`)
}
function showIssueRelateHelp() {
  console.log(`Usage: linear-cli issue relate <id-or-key> <related-id-or-key> [options]

Create a relation between two issues

Arguments:
  id-or-key              The issue to relate from
  related-id-or-key      The issue to relate to

Options:
  --type <type>    Relation type: blocks, duplicate, related (default: blocks)
  --json           Output raw JSON
  -h, --help       Show help

Examples:
  linear-cli issue relate NES-123 NES-456 --type blocks
  linear-cli issue relate NES-123 NES-456 --type related`)
}
function showIssueUploadHelp() {
  console.log(`Usage: linear-cli issue upload <id-or-key> <file> [options]

Upload a file to an issue. Creates a sidebar attachment and optionally posts a comment with the file embedded inline.

Arguments:
  id-or-key             Issue identifier (e.g., NES-123 or full UUID)
  file                  Path to the file to upload

Options:
  --comment <text>      Also post a comment with the file embedded at the end
  --comment-file <file> Read comment body from file (use "-" for stdin)
  --title <text>        Title for the sidebar attachment (default: filename)
  --no-attachment       Skip creating a sidebar attachment
  --content-type <mime> Override auto-detected content type
  --json                Output JSON: { asset_url, comment_url, attachment_id }
  -h, --help            Show help

Examples:
  linear-cli issue upload NES-123 ./session.webm --comment "Validation walkthrough — passed"
  linear-cli issue upload NES-123 ./diagram.png --title "Architecture sketch"
  linear-cli issue upload NES-123 ./report.pdf --no-attachment --json`)
}
function getLinearClient() {
  const apiKey = process.env.LINEAR_API_KEY
  if (!apiKey) {
    console.error(`Error: LINEAR_API_KEY not configured.
Run: ${linearDir}/linear setup`)
    process.exit(1)
  }
  try {
    return new LinearClient({ apiKey })
  } catch (error) {
    console.error(`Error: Failed to initialize Linear client

Make sure @linear/sdk is installed:
  cd linear/
  npm install`)
    process.exit(1)
  }
}

// Helper to read file or stdin
function readBodyFile(path) {
  if (path === "-" || path === true) {
    // Read from stdin (path might be true if --body-file is passed without value)
    try {
      return readFileSync(0, "utf-8")
    } catch (error) {
      console.error("Error: Could not read from stdin")
      process.exit(1)
    }
  } else {
    // Read from file
    try {
      return readFileSync(path, "utf-8")
    } catch (error) {
      console.error(`Error: Could not read file: ${path}`)
      process.exit(1)
    }
  }
}

// Helper to parse label input (supports comma-separated or array)
function parseLabels(labelInput) {
  if (!labelInput) return []

  const labels = Array.isArray(labelInput) ? labelInput : [labelInput]
  const result = []

  for (const label of labels) {
    // Split by comma in case user does --label "bug,feature"
    const split = label.split(",").map((l) => l.trim()).filter(Boolean)
    result.push(...split)
  }

  return result
}

// Helper to resolve assignee (handle @me)
async function resolveAssignee(client, assigneeInput) {
  if (!assigneeInput) return null
  if (assigneeInput === "@me") {
    const viewer = await client.viewer
    return viewer.id
  }
  return assigneeInput
}

// Helper to find labels by name for a team (falls back to workspace labels)
async function findLabels(client, teamId, labelNames) {
  const graphQLClient = client.client

  // Get team labels and workspace labels in one query
  const response = await graphQLClient.rawRequest(
    `query getLabels($teamId: String!) {
      team(id: $teamId) {
        labels {
          nodes {
            id
            name
          }
        }
      }
      issueLabels(first: 250) {
        nodes {
          id
          name
        }
      }
    }`,
    { teamId }
  )

  const teamLabels = response.data.team.labels.nodes
  const workspaceLabels = response.data.issueLabels.nodes
  const labelIds = []
  const notFound = []

  for (const labelName of labelNames) {
    // Search team labels first, then fall back to workspace labels
    const label =
      teamLabels.find(
        (l) => l.name.toLowerCase() === labelName.toLowerCase()
      ) ||
      workspaceLabels.find(
        (l) => l.name.toLowerCase() === labelName.toLowerCase()
      )
    if (label) {
      labelIds.push(label.id)
    } else {
      notFound.push(labelName)
    }
  }

  if (notFound.length > 0) {
    console.error(`Error: Label(s) not found: ${notFound.join(", ")}`)
    console.error(`\nAvailable labels for this team:`)
    if (teamLabels.length === 0) {
      console.error("  (no team labels available)")
    } else {
      for (const label of teamLabels) {
        console.error(`  - ${label.name}`)
      }
    }
    console.error(`\nWorkspace labels:`)
    for (const label of workspaceLabels) {
      console.error(`  - ${label.name}`)
    }
    process.exit(1)
  }

  return labelIds
}
async function listUsers(flags) {
  const client = getLinearClient()
  const users = await client.users()
  if (flags.json) {
    console.log(JSON.stringify(users.nodes, null, 2))
    return
  }
  console.log("Users\n")
  for (const user of users.nodes) {
    console.log(`#${user.id}\t${user.name}\t${user.email}`)
  }
}
async function listTeams(flags) {
  const client = getLinearClient()
  const teams = await client.teams()
  if (flags.json) {
    console.log(JSON.stringify(teams.nodes, null, 2))
    return
  }
  console.log("Teams\n")
  for (const team of teams.nodes) {
    console.log(`#${team.id}\t${team.name}\t${team.key}`)
  }
}
// The sidebar hexagon color is `project.color` — a MANUAL accent the team
// repurposed as the real status signal (it does NOT track Linear's `status`):
//   green  #4cb782 = active now
//   yellow #f2c94c = ramping (planning/starting OR rolling off)
//   gray   #bec2c8 (default) / anything else = backlog / dormant
const PROJECT_TIER = {
  "#4cb782": { key: "active", label: "🟢 ACTIVE" },
  "#f2c94c": { key: "ramping", label: "🟡 RAMPING (planning / rolling off)" },
}
const TIER_DORMANT = { key: "backlog", label: "⚪ BACKLOG / dormant" }
const TIER_ORDER = ["active", "ramping", "backlog"]
function projectTier(p) {
  return PROJECT_TIER[(p.color || "").toLowerCase()] || TIER_DORMANT
}
// health is a separate self-reported signal (the lead's weekly check-in).
const HEALTH_LABEL = { onTrack: "🟢 on-track", atRisk: "🟡 at-risk", offTrack: "🔴 off-track" }

async function listProjects(flags) {
  const client = getLinearClient()
  const graphQLClient = client.client
  const limit = flags.limit ? parseInt(flags.limit, 10) : 200
  const response = await graphQLClient.rawRequest(
    `query listProjects($first: Int!) {
      projects(first: $first, orderBy: updatedAt) {
        nodes {
          id name url color health progress
          status { name type }
          lead { name }
        }
      }
    }`,
    { first: limit }
  )
  let projects = response.data.projects.nodes
  // --active = only the green tier; --no-backlog drops the dormant pile.
  if (flags.active) projects = projects.filter((p) => projectTier(p).key === "active")
  else if (flags["no-backlog"]) projects = projects.filter((p) => projectTier(p).key !== "backlog")

  if (flags.json) {
    console.log(JSON.stringify(projects, null, 2))
    return
  }

  const groups = { active: [], ramping: [], backlog: [] }
  for (const p of projects) groups[projectTier(p).key].push(p)
  const label = { active: "🟢 ACTIVE", backlog: "⚪ BACKLOG / dormant" }

  const printRow = (p) => {
    const status = p.status?.name || "—"
    const health = p.health ? HEALTH_LABEL[p.health] || p.health : "—"
    const pct = (p.progress != null ? `${Math.round(p.progress * 100)}%` : "—").padStart(4)
    const lead = p.lead?.name || "unassigned"
    console.log(`  ${p.name.slice(0, 40).padEnd(40)} ${pct}  ${status.padEnd(13)} ${health.padEnd(11)} ${lead}`)
  }
  const byProgressDesc = (a, b) => (b.progress || 0) - (a.progress || 0)
  const section = (heading, list) => {
    if (!list.length) return
    console.log(`${heading}  (${list.length})\n`)
    list.sort(byProgressDesc).forEach(printRow)
    console.log()
  }

  for (const key of TIER_ORDER) {
    const list = groups[key]
    if (!list.length) continue
    if (key === "ramping") {
      // Same yellow color for both directions — split by progress:
      // far along = rolling off (winding down), barely started = ramping up.
      const thr = (flags["ramp-threshold"] ? parseInt(flags["ramp-threshold"], 10) : 50) / 100
      section("🟡 ↘ ROLLING OFF", list.filter((p) => (p.progress || 0) >= thr))
      section("🟡 ↗ RAMPING UP / planning", list.filter((p) => (p.progress || 0) < thr))
    } else {
      section(label[key], list)
    }
  }
}
async function listIssues(flags) {
  const client = getLinearClient()

  // Build filter JSON
  const filter = {}
  if (flags.team) {
    filter.team = { id: { eq: flags.team } }
  }
  if (flags.assignee) {
    filter.assignee = { id: { eq: flags.assignee } }
  }
  if (flags.status) {
    filter.state = { name: { eq: flags.status } }
  }
  const limit = flags.limit ? parseInt(flags.limit, 10) : 50

  // Use GraphQL to preload all relations in a single query
  const graphQLClient = client.client
  const response = await graphQLClient.rawRequest(
    `query listIssues($first: Int!, $filter: IssueFilter, $orderBy: PaginationOrderBy!) {
      issues(first: $first, filter: $filter, orderBy: $orderBy) {
        nodes {
          id
          identifier
          title
          state {
            name
          }
          assignee {
            name
            email
          }
        }
      }
    }`,
    {
      first: limit,
      filter: Object.keys(filter).length > 0 ? filter : undefined,
      orderBy: "updatedAt"
    }
  )

  const issues = response.data.issues.nodes

  if (flags.json) {
    console.log(JSON.stringify(issues, null, 2))
    return
  }

  console.log("Issues\n")
  for (const issue of issues) {
    const assigneeName = issue.assignee?.name || "Unassigned"
    console.log(`#${issue.identifier}\t${issue.title}\t${issue.state?.name}\t${assigneeName}`)
  }
}
async function getIssue(identifier, flags) {
  const client = getLinearClient()
  const graphQLClient = client.client

  let issue
  try {
    if (identifier.includes("-")) {
      // Looks like an identifier (ENG-123)
      const [teamKey, issueNumber] = identifier.toUpperCase().split("-")
      const response = await graphQLClient.rawRequest(
        `query getIssueByIdentifier($teamKey: String!, $issueNumber: Float!) {
          issues(filter: { team: { key: { eq: $teamKey } }, number: { eq: $issueNumber } }) {
            nodes {
              id
              identifier
              title
              description
              priority
              estimate
              dueDate
              createdAt
              updatedAt
              state {
                name
              }
              assignee {
                name
                email
              }
              team {
                name
                key
              }
              parent {
                identifier
                title
              }
              project {
                id
                name
              }
              labels {
                nodes {
                  name
                }
              }
              comments {
                nodes {
                  body
                  createdAt
                  user {
                    name
                  }
                }
              }
              attachments {
                nodes {
                  id
                  title
                  url
                  sourceType
                  createdAt
                }
              }
            }
          }
        }`,
        { teamKey, issueNumber: parseInt(issueNumber) }
      )
      issue = response.data.issues.nodes[0]
    } else {
      // Assume it's a UUID
      const response = await graphQLClient.rawRequest(
        `query getIssueById($id: String!) {
          issue(id: $id) {
            id
            identifier
            title
            description
            priority
            estimate
            dueDate
            createdAt
            updatedAt
            state {
              name
            }
            assignee {
              name
              email
            }
            team {
              name
              key
            }
            parent {
              identifier
              title
            }
            project {
              id
              name
            }
            labels {
              nodes {
                name
              }
            }
            comments {
              nodes {
                body
                createdAt
                user {
                  name
                }
              }
            }
            attachments {
              nodes {
                id
                title
                url
                sourceType
                createdAt
              }
            }
          }
        }`,
        { id: identifier }
      )
      issue = response.data.issue
    }
  } catch (error) {
    console.error(`Error: Issue not found: ${identifier}`)
    process.exit(1)
  }

  if (!issue) {
    console.error(`Error: Issue not found: ${identifier}`)
    process.exit(1)
  }

  if (flags.json) {
    console.log(JSON.stringify(issue, null, 2))
    return
  }

  const priorityMap = {
    0: "None",
    1: "Urgent (P0)",
    2: "High (P1)",
    3: "Medium (P2)",
    4: "Low (P3)",
  }

  console.log(`Issue: #${issue.identifier}\n`)
  console.log(`Title:\t\t${issue.title}`)
  console.log(`Status:\t\t${issue.state?.name || "Unknown"}`)
  console.log(`Assignee:\t${issue.assignee ? `${issue.assignee.name} (${issue.assignee.email})` : "Unassigned"}`)
  console.log(`Team:\t\t${issue.team.name} (${issue.team.key})`)
  console.log(`Priority:\t${priorityMap[issue.priority] || "None"}`)
  console.log(`Labels:\t\t${issue.labels.nodes.map((l) => l.name).join(", ") || "None"}`)
  if (issue.parent) {
    console.log(`Parent:\t\t#${issue.parent.identifier} - ${issue.parent.title}`)
  }
  if (issue.project) {
    console.log(`Project:\t${issue.project.name}`)
  }
  if (issue.estimate) {
    console.log(`Estimate:\t${issue.estimate} points`)
  }
  if (issue.dueDate) {
    console.log(`Due Date:\t${issue.dueDate}`)
  }
  console.log(`Created:\t${new Date(issue.createdAt).toISOString().split("T")[0]}`)
  console.log(`Updated:\t${new Date(issue.updatedAt).toISOString().split("T")[0]}`)

  if (issue.description) {
    console.log(`\nDescription:`)
    console.log(issue.description)
  }

  if (issue.attachments?.nodes?.length > 0) {
    console.log(`\nAttachments:`)
    for (const attachment of issue.attachments.nodes) {
      const date = new Date(attachment.createdAt).toISOString().split("T")[0]
      const title = attachment.title || attachment.sourceType || "Attachment"
      console.log(`  [${date}] ${title}`)
      console.log(`    URL: ${attachment.url}`)
    }
  }

  if (issue.comments.nodes.length > 0) {
    console.log(`\nComments:`)
    for (const comment of issue.comments.nodes) {
      const date = new Date(comment.createdAt).toISOString().split("T")[0]
      console.log(`  [${date}] ${comment.user?.name}: ${comment.body}`)
    }
  }
}
async function addComment(identifier, text, flags) {
  const client = getLinearClient()
  // Find issue first
  let issue
  try {
    if (identifier.includes("-")) {
      const issues = await client.issues({ filter: { number: { eq: parseInt(identifier.split("-")[1]) } } })
      issue = issues.nodes.find((i) => i.identifier === identifier.toUpperCase())
    } else {
      issue = await client.issue(identifier)
    }
  } catch (error) {
    console.error(`Error: Issue not found: ${identifier}`)
    process.exit(1)
  }
  if (!issue) {
    console.error(`Error: Issue not found: ${identifier}`)
    process.exit(1)
  }
  const response = await client.createComment({
    issueId: issue.id,
    body: text,
  })
  const comment = await response.comment
  if (flags.json) {
    console.log(JSON.stringify(comment, null, 2))
    return
  }
  console.log(`✓ Comment added to #${issue.identifier}`)
}
async function updateIssue(identifier, flags) {
  const client = getLinearClient()
  // Find issue first
  let issue
  try {
    if (identifier.includes("-")) {
      const issues = await client.issues({ filter: { number: { eq: parseInt(identifier.split("-")[1]) } } })
      issue = issues.nodes.find((i) => i.identifier === identifier.toUpperCase())
    } else {
      issue = await client.issue(identifier)
    }
  } catch (error) {
    console.error(`Error: Issue not found: ${identifier}`)
    process.exit(1)
  }
  if (!issue) {
    console.error(`Error: Issue not found: ${identifier}`)
    process.exit(1)
  }
  const updates = {}

  // Handle status
  if (flags.status) {
    // Find state by name
    const team = await issue.team
    const states = await team.states()
    const state = states.nodes.find((s) => s.name.toLowerCase() === flags.status.toLowerCase())
    if (state) {
      updates.stateId = state.id
    } else {
      console.error(`Error: Status '${flags.status}' not found`)
      process.exit(1)
    }
  }

  // Handle assignee with @me support
  const assigneeId = await resolveAssignee(client, flags.assignee)
  if (assigneeId) {
    updates.assigneeId = assigneeId
  }

  // Handle priority
  if (flags.priority !== undefined) {
    updates.priority = parseInt(flags.priority, 10)
  }

  // Handle title
  if (flags.title) {
    updates.title = flags.title
  }

  // Handle body/description
  if (flags["body-file"]) {
    updates.description = readBodyFile(flags["body-file"])
  } else if (flags.body) {
    updates.description = flags.body
  }

  // Handle labels
  const labelNames = parseLabels(flags.label)
  if (labelNames.length > 0) {
    const team = await issue.team
    const labelIds = await findLabels(client, team.id, labelNames)
    updates.labelIds = labelIds
  }

  // Handle project
  if (flags.project) {
    updates.projectId = flags.project
  }

  // Handle parent
  if (flags.parent) {
    let parentIssue
    try {
      if (flags.parent.includes("-")) {
        const issues = await client.issues({
          filter: { number: { eq: parseInt(flags.parent.split("-")[1]) } },
        })
        parentIssue = issues.nodes.find((i) => i.identifier === flags.parent.toUpperCase())
      } else {
        parentIssue = await client.issue(flags.parent)
      }
    } catch (error) {
      console.error(`Error: Parent issue not found: ${flags.parent}`)
      process.exit(1)
    }
    if (!parentIssue) {
      console.error(`Error: Parent issue not found: ${flags.parent}`)
      process.exit(1)
    }
    updates.parentId = parentIssue.id
  }

  // Handle estimate
  if (flags.estimate !== undefined) {
    updates.estimate = parseFloat(flags.estimate)
  }

  // Handle due date
  if (flags["due-date"]) {
    const dateRegex = /^\d{4}-\d{2}-\d{2}$/
    if (!dateRegex.test(flags["due-date"])) {
      console.error(`Error: Invalid date format. Use YYYY-MM-DD (e.g., 2025-12-31)`)
      process.exit(1)
    }
    updates.dueDate = flags["due-date"]
  }

  if (Object.keys(updates).length === 0) {
    console.error(`Error: No updates specified

Run 'linear-cli update --help' for available options`)
    process.exit(1)
  }
  const response = await client.updateIssue(issue.id, updates)
  const updatedIssue = await response.issue
  if (flags.json) {
    console.log(JSON.stringify(updatedIssue, null, 2))
    return
  }
  console.log(`✓ Issue #${issue.identifier} updated`)
}
async function createIssue(title, flags) {
  const client = getLinearClient()
  if (!flags.team) {
    console.error(`Error: --team flag is required

Run 'linear-cli create --help' for usage`)
    process.exit(1)
  }
  const input = {
    teamId: flags.team,
    title,
  }

  // Handle body/description
  if (flags["body-file"]) {
    input.description = readBodyFile(flags["body-file"])
  } else if (flags.body) {
    input.description = flags.body
  }

  // Handle assignee with @me support
  const assigneeId = await resolveAssignee(client, flags.assignee)
  if (assigneeId) {
    input.assigneeId = assigneeId
  }

  // Handle labels
  const labelNames = parseLabels(flags.label)
  if (labelNames.length > 0) {
    const labelIds = await findLabels(client, flags.team, labelNames)
    input.labelIds = labelIds
  }

  // Handle project
  if (flags.project) {
    input.projectId = flags.project
  }

  // Handle parent (for sub-issues)
  if (flags.parent) {
    // Need to resolve parent identifier to ID
    let parentIssue
    try {
      if (flags.parent.includes("-")) {
        const issues = await client.issues({
          filter: { number: { eq: parseInt(flags.parent.split("-")[1]) } },
        })
        parentIssue = issues.nodes.find((i) => i.identifier === flags.parent.toUpperCase())
      } else {
        parentIssue = await client.issue(flags.parent)
      }
    } catch (error) {
      console.error(`Error: Parent issue not found: ${flags.parent}`)
      process.exit(1)
    }
    if (!parentIssue) {
      console.error(`Error: Parent issue not found: ${flags.parent}`)
      process.exit(1)
    }
    input.parentId = parentIssue.id
  }

  // Handle priority
  if (flags.priority !== undefined) {
    input.priority = parseInt(flags.priority, 10)
  }

  // Handle estimate
  if (flags.estimate !== undefined) {
    input.estimate = parseFloat(flags.estimate)
  }

  // Handle due date
  if (flags["due-date"]) {
    // Validate date format
    const dateRegex = /^\d{4}-\d{2}-\d{2}$/
    if (!dateRegex.test(flags["due-date"])) {
      console.error(`Error: Invalid date format. Use YYYY-MM-DD (e.g., 2025-12-31)`)
      process.exit(1)
    }
    input.dueDate = flags["due-date"]
  }

  // Handle status
  if (flags.status) {
    // Find state by name
    const team = await client.team(flags.team)
    const states = await team.states()
    const state = states.nodes.find((s) => s.name.toLowerCase() === flags.status.toLowerCase())
    if (state) {
      input.stateId = state.id
    } else {
      console.error(`Error: Status '${flags.status}' not found`)
      process.exit(1)
    }
  }

  const response = await client.createIssue(input)
  const issue = await response.issue
  if (!issue) {
    console.error("Error: Failed to create issue")
    process.exit(1)
  }
  if (flags.json) {
    console.log(JSON.stringify(issue, null, 2))
    return
  }
  console.log(`✓ Issue created: #${issue.identifier}`)
  console.log(`  Title: ${issue.title}`)
  console.log(`  URL: ${issue.url}`)
}
async function deleteIssue(identifier, flags) {
  const client = getLinearClient()
  // Find issue first
  let issue
  try {
    if (identifier.includes("-")) {
      const issues = await client.issues({ filter: { number: { eq: parseInt(identifier.split("-")[1]) } } })
      issue = issues.nodes.find((i) => i.identifier === identifier.toUpperCase())
    } else {
      issue = await client.issue(identifier)
    }
  } catch (error) {
    console.error(`Error: Issue not found: ${identifier}`)
    process.exit(1)
  }
  if (!issue) {
    console.error(`Error: Issue not found: ${identifier}`)
    process.exit(1)
  }
  const response = await client.deleteIssue(issue.id)
  const success = await response.success
  if (flags.json) {
    console.log(JSON.stringify({ success }, null, 2))
    return
  }
  if (success) {
    console.log(`✓ Issue #${issue.identifier} deleted (moved to trash)`)
  } else {
    console.error(`Error: Failed to delete issue #${issue.identifier}`)
    process.exit(1)
  }
}

// Helper to extract inline image URLs from markdown
function extractImageUrls(text) {
  if (!text) return []
  const images = []
  // Match markdown images: ![alt](url)
  const markdownRegex = /!\[([^\]]*)\]\(([^)]+)\)/g
  let match
  while ((match = markdownRegex.exec(text)) !== null) {
    const [, alt, url] = match
    if (url.includes("uploads.linear.app")) {
      // Extract filename from alt text or URL
      const urlParts = url.split("/")
      const id = urlParts[urlParts.length - 1]
      images.push({
        alt: alt || "image",
        url,
        id,
        filename: alt ? alt.replace(/[^a-zA-Z0-9.-]/g, "_") : `image_${id.slice(0, 8)}`
      })
    }
  }
  return images
}

async function getIssueImages(identifier, flags) {
  const client = getLinearClient()
  const graphQLClient = client.client

  let issue
  try {
    if (identifier.includes("-")) {
      const [teamKey, issueNumber] = identifier.toUpperCase().split("-")
      const response = await graphQLClient.rawRequest(
        `query getIssueDescription($teamKey: String!, $issueNumber: Float!) {
          issues(filter: { team: { key: { eq: $teamKey } }, number: { eq: $issueNumber } }) {
            nodes {
              id
              identifier
              title
              description
            }
          }
        }`,
        { teamKey, issueNumber: parseInt(issueNumber) }
      )
      issue = response.data.issues.nodes[0]
    } else {
      const response = await graphQLClient.rawRequest(
        `query getIssueDescription($id: String!) {
          issue(id: $id) {
            id
            identifier
            title
            description
          }
        }`,
        { id: identifier }
      )
      issue = response.data.issue
    }
  } catch (error) {
    console.error(`Error: Issue not found: ${identifier}`)
    process.exit(1)
  }

  if (!issue) {
    console.error(`Error: Issue not found: ${identifier}`)
    process.exit(1)
  }

  const images = extractImageUrls(issue.description)

  if (images.length === 0) {
    if (flags.json) {
      console.log(JSON.stringify({ issue: issue.identifier, images: [] }, null, 2))
    } else {
      console.log(`No inline images found in #${issue.identifier}`)
    }
    return
  }

  if (flags.json && !flags.download) {
    console.log(JSON.stringify({ issue: issue.identifier, images }, null, 2))
    return
  }

  if (flags.download) {
    const outputDir = flags.output || "."

    // Create output directory if it doesn't exist
    if (!existsSync(outputDir)) {
      mkdirSync(outputDir, { recursive: true })
    }

    const apiKey = process.env.LINEAR_API_KEY
    const downloaded = []

    console.log(`Downloading ${images.length} image(s) from #${issue.identifier}...\n`)

    for (const image of images) {
      try {
        const response = await fetch(image.url, {
          headers: { Authorization: apiKey }
        })

        if (!response.ok) {
          console.error(`  ✗ Failed to download: ${image.alt} (HTTP ${response.status})`)
          continue
        }

        // Get content type to determine extension
        const contentType = response.headers.get("content-type") || ""
        let ext = ".png"
        if (contentType.includes("jpeg") || contentType.includes("jpg")) ext = ".jpg"
        else if (contentType.includes("gif")) ext = ".gif"
        else if (contentType.includes("webp")) ext = ".webp"
        else if (contentType.includes("svg")) ext = ".svg"

        // Use original extension if filename has one
        const hasExt = /\.[a-z]{3,4}$/i.test(image.filename)
        const filename = hasExt ? image.filename : `${image.filename}${ext}`
        const filepath = join(outputDir, filename)

        const buffer = await response.buffer()
        writeFileSync(filepath, buffer)

        downloaded.push({ ...image, filepath, size: buffer.length })
        console.log(`  ✓ ${filename} (${(buffer.length / 1024).toFixed(1)} KB)`)
      } catch (error) {
        console.error(`  ✗ Failed to download: ${image.alt} - ${error.message}`)
      }
    }

    if (flags.json) {
      console.log(JSON.stringify({ issue: issue.identifier, downloaded }, null, 2))
    } else {
      console.log(`\n${downloaded.length}/${images.length} image(s) downloaded to ${outputDir}`)
    }
  } else {
    // List mode
    console.log(`Images in #${issue.identifier}:\n`)
    for (let i = 0; i < images.length; i++) {
      const img = images[i]
      console.log(`  ${i + 1}. ${img.alt}`)
      console.log(`     URL: ${img.url}`)
    }
    console.log(`\nUse --download to save images to disk`)
  }
}

// Helper to resolve team by key or ID
async function resolveTeamId(client, keyOrId) {
  if (!keyOrId) return null
  const graphQLClient = client.client
  // Try as key first (short strings like NES, CON)
  if (keyOrId.length <= 5 && !keyOrId.includes("-")) {
    const response = await graphQLClient.rawRequest(
      `query getTeams { teams { nodes { id key name } } }`
    )
    const team = response.data.teams.nodes.find(
      (t) => t.key.toLowerCase() === keyOrId.toLowerCase()
    )
    if (team) return team.id
  }
  return keyOrId // assume it's a UUID
}

async function listTeamStates(teamKeyOrId, flags) {
  const client = getLinearClient()
  const graphQLClient = client.client
  const teamId = teamKeyOrId ? await resolveTeamId(client, teamKeyOrId) : null

  const response = await graphQLClient.rawRequest(
    `query getStates { workflowStates(first: 200) { nodes { id name type position team { key name } } } }`
  )
  let states = response.data.workflowStates.nodes
  if (teamId) {
    // Filter and also resolve key for display
    const teamsResponse = await graphQLClient.rawRequest(
      `query getTeam($id: String!) { team(id: $id) { key name } }`,
      { id: teamId }
    )
    const teamKey = teamsResponse.data.team.key
    states = states.filter((s) => s.team.key === teamKey)
  }

  // Sort by type order then position
  const typeOrder = { triage: 0, backlog: 1, unstarted: 2, started: 3, completed: 4, canceled: 5 }
  states.sort((a, b) => (typeOrder[a.type] ?? 99) - (typeOrder[b.type] ?? 99) || a.position - b.position)

  if (flags.json) {
    console.log(JSON.stringify(states, null, 2))
    return
  }

  console.log("Workflow States\n")
  let lastType = ""
  for (const state of states) {
    if (state.type !== lastType) {
      if (lastType) console.log()
      console.log(`  [${state.type}]`)
      lastType = state.type
    }
    const teamLabel = teamId ? "" : `\t(${state.team.key})`
    console.log(`    ${state.name}${teamLabel}\t#${state.id}`)
  }
}

async function listTeamLabels(teamKeyOrId, flags) {
  const client = getLinearClient()
  const graphQLClient = client.client

  let query, variables
  if (teamKeyOrId) {
    const teamId = await resolveTeamId(client, teamKeyOrId)
    query = `query getTeamLabels($teamId: String!) {
      team(id: $teamId) {
        labels { nodes { id name color parent { id name } } }
      }
    }`
    variables = { teamId }
  } else {
    query = `query getAllLabels { issueLabels(first: 250) { nodes { id name color parent { id name } } } }`
    variables = {}
  }

  const response = await graphQLClient.rawRequest(query, variables)
  const labels = teamKeyOrId
    ? response.data.team.labels.nodes
    : response.data.issueLabels.nodes

  if (flags.json) {
    console.log(JSON.stringify(labels, null, 2))
    return
  }

  if (flags.group) {
    // Group by parent
    const groups = {}
    const standalone = []
    for (const label of labels) {
      if (label.parent) {
        const parentName = label.parent.name
        if (!groups[parentName]) groups[parentName] = []
        groups[parentName].push(label)
      } else {
        standalone.push(label)
      }
    }

    console.log("Labels\n")
    for (const [parentName, children] of Object.entries(groups).sort()) {
      console.log(`  ${parentName}:`)
      for (const label of children.sort((a, b) => a.name.localeCompare(b.name))) {
        console.log(`    ${label.name}\t${label.color}`)
      }
      console.log()
    }
    if (standalone.length > 0) {
      console.log("  (no parent):")
      for (const label of standalone.sort((a, b) => a.name.localeCompare(b.name))) {
        console.log(`    ${label.name}\t${label.color}`)
      }
    }
  } else {
    console.log("Labels\n")
    for (const label of labels) {
      const parent = label.parent ? ` (${label.parent.name})` : ""
      console.log(`  ${label.name}${parent}\t${label.color}\t#${label.id}`)
    }
  }
}

async function listTemplates(flags) {
  const client = getLinearClient()
  const graphQLClient = client.client

  const response = await graphQLClient.rawRequest(
    `query getTemplates { templates { id name type description team { key name } } }`
  )
  let templates = response.data.templates

  if (flags.team) {
    templates = templates.filter((t) => t.team && t.team.key.toLowerCase() === flags.team.toLowerCase())
  }

  if (flags.json) {
    console.log(JSON.stringify(templates, null, 2))
    return
  }

  console.log("Templates\n")
  for (const t of templates) {
    const teamLabel = t.team ? `(${t.team.key})` : "(Org-wide)"
    console.log(`  ${teamLabel}\t${t.type}\t${t.name}\t#${t.id}`)
  }
}

async function viewTemplate(templateId, flags) {
  const client = getLinearClient()
  const graphQLClient = client.client

  const response = await graphQLClient.rawRequest(
    `query getTemplate($id: String!) { template(id: $id) { id name type description templateData team { key name } } }`,
    { id: templateId }
  )
  const template = response.data.template

  if (flags.json) {
    const td = typeof template.templateData === "string"
      ? JSON.parse(template.templateData)
      : template.templateData
    console.log(JSON.stringify({ ...template, templateData: td }, null, 2))
    return
  }

  const td = typeof template.templateData === "string"
    ? JSON.parse(template.templateData)
    : template.templateData

  const teamLabel = template.team ? `${template.team.name} (${template.team.key})` : "Org-wide"
  console.log(`Template: ${template.name}`)
  console.log(`Type: ${template.type}`)
  console.log(`Team: ${teamLabel}`)
  console.log(`ID: ${template.id}`)
  if (td.title) console.log(`Title: ${td.title}`)
  if (td.labelIds?.length > 0) console.log(`Labels: ${td.labelIds.join(", ")}`)
  if (td.stateId) console.log(`State: ${td.stateId}`)
  if (td.priority !== undefined) console.log(`Priority: ${td.priority}`)

  // Extract description text from descriptionData
  if (td.descriptionData) {
    console.log("\nDescription:")
    const lines = extractDescriptionText(td.descriptionData)
    console.log(lines.join("\n"))
  } else if (td.description) {
    console.log("\nDescription:")
    console.log(td.description)
  }
}

// Helper to extract text from ProseMirror/TipTap descriptionData
function extractDescriptionText(node) {
  const result = []
  if (node.type === "heading") {
    const level = node.attrs?.level || 2
    const prefix = "#".repeat(level) + " "
    const texts = (node.content || []).filter((c) => c.type === "text").map((c) => c.text)
    result.push(prefix + texts.join(""))
  } else if (node.type === "paragraph") {
    const texts = (node.content || []).filter((c) => c.type === "text").map((c) => c.text)
    result.push(texts.join(""))
  } else if (node.type === "todo_list" || node.type === "taskList") {
    for (const item of node.content || []) {
      for (const p of item.content || []) {
        const texts = (p.content || []).filter((c) => c.type === "text").map((c) => c.text)
        const checked = item.attrs?.checked ? "x" : " "
        result.push(`- [${checked}] ${texts.join("")}`)
      }
    }
  } else if (node.type === "bullet_list" || node.type === "bulletList") {
    for (const item of node.content || []) {
      for (const p of item.content || []) {
        const texts = (p.content || []).filter((c) => c.type === "text").map((c) => c.text)
        result.push(`- ${texts.join("")}`)
      }
    }
  } else if (node.type === "blockquote") {
    for (const child of node.content || []) {
      const lines = extractDescriptionText(child)
      result.push(...lines.map((l) => `> ${l}`))
    }
  } else if (node.type === "code_block" || node.type === "codeBlock") {
    result.push("```")
    const texts = (node.content || []).filter((c) => c.type === "text").map((c) => c.text)
    result.push(texts.join(""))
    result.push("```")
  } else if (node.type === "horizontal_rule" || node.type === "horizontalRule") {
    result.push("---")
  } else if (node.type === "table") {
    for (const row of node.content || []) {
      const cells = (row.content || []).map((cell) => {
        const cellTexts = []
        for (const p of cell.content || []) {
          const texts = (p.content || []).filter((c) => c.type === "text").map((c) => c.text)
          cellTexts.push(texts.join(""))
        }
        return cellTexts.join(" ")
      })
      result.push("| " + cells.join(" | ") + " |")
    }
  }

  // Recurse into children for doc/other container types
  if (["doc", "list_item", "listItem"].includes(node.type)) {
    for (const child of node.content || []) {
      result.push(...extractDescriptionText(child))
    }
  }

  return result
}

// Helper to look up an issue by NES-style key or UUID
async function resolveIssueByIdentifier(client, identifier) {
  if (identifier.includes("-") && !/^[0-9a-f-]{36}$/i.test(identifier)) {
    const issues = await client.issues({
      filter: { number: { eq: parseInt(identifier.split("-")[1]) } },
    })
    const issue = issues.nodes.find(
      (i) => i.identifier === identifier.toUpperCase()
    )
    if (!issue) throw new Error(`Issue not found: ${identifier}`)
    return issue
  }
  return await client.issue(identifier)
}

// Minimal extension → mime map. Linear accepts arbitrary content types,
// but matching the file's real type lets the UI render inline players/previews.
function detectContentType(filename) {
  const ext = extname(filename).toLowerCase()
  const map = {
    ".webm": "video/webm",
    ".mp4": "video/mp4",
    ".mov": "video/quicktime",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".svg": "image/svg+xml",
    ".pdf": "application/pdf",
    ".json": "application/json",
    ".har": "application/json",
    ".txt": "text/plain",
    ".md": "text/markdown",
    ".html": "text/html",
    ".zip": "application/zip",
  }
  return map[ext] || "application/octet-stream"
}

async function uploadFileToIssue(identifier, filePath, flags) {
  const client = getLinearClient()
  const graphQLClient = client.client

  if (!existsSync(filePath)) {
    console.error(`Error: File not found: ${filePath}`)
    process.exit(1)
  }
  const stats = statSync(filePath)
  if (!stats.isFile()) {
    console.error(`Error: Not a file: ${filePath}`)
    process.exit(1)
  }

  let issue
  try {
    issue = await resolveIssueByIdentifier(client, identifier)
  } catch (error) {
    console.error(`Error: ${error.message}`)
    process.exit(1)
  }

  const filename = basename(filePath)
  const contentType = flags["content-type"] || detectContentType(filename)
  const size = stats.size

  // Step 1: ask Linear for a signed upload URL.
  const uploadResp = await graphQLClient.rawRequest(
    `mutation FileUpload($contentType: String!, $filename: String!, $size: Int!) {
      fileUpload(contentType: $contentType, filename: $filename, size: $size) {
        success
        uploadFile {
          uploadUrl
          assetUrl
          headers { key value }
        }
      }
    }`,
    { contentType, filename, size }
  )
  const uploadFile = uploadResp.data?.fileUpload?.uploadFile
  if (!uploadResp.data?.fileUpload?.success || !uploadFile) {
    console.error(`Error: Linear refused fileUpload for ${filename}`)
    process.exit(1)
  }

  // Step 2: PUT the bytes to the signed URL with the headers Linear specified.
  const headers = { "Content-Type": contentType, "Content-Length": String(size) }
  for (const h of uploadFile.headers || []) headers[h.key] = h.value
  const fileBuffer = readFileSync(filePath)
  const putResp = await fetch(uploadFile.uploadUrl, {
    method: "PUT",
    headers,
    body: fileBuffer,
  })
  if (!putResp.ok) {
    const text = await putResp.text().catch(() => "")
    console.error(
      `Error: Upload PUT failed (${putResp.status} ${putResp.statusText})${text ? `\n${text.slice(0, 500)}` : ""}`
    )
    process.exit(1)
  }

  // Step 3: optionally register a sidebar attachment record.
  let attachmentId = null
  if (!flags["no-attachment"]) {
    const title = flags.title || filename
    const attachResp = await graphQLClient.rawRequest(
      `mutation CreateAttachment($input: AttachmentCreateInput!) {
        attachmentCreate(input: $input) {
          success
          attachment { id }
        }
      }`,
      { input: { issueId: issue.id, url: uploadFile.assetUrl, title } }
    )
    if (!attachResp.data?.attachmentCreate?.success) {
      console.error(`Warning: Could not create sidebar attachment record`)
    } else {
      attachmentId = attachResp.data.attachmentCreate.attachment.id
    }
  }

  // Step 4: optionally post a comment with the file embedded at the end.
  // Image-style markdown is what Linear's renderer uses for inline media,
  // so video/image both go in via the same syntax — the renderer picks the
  // right player based on content type at the asset URL.
  let commentUrl = null
  let commentText = null
  if (flags["comment-file"]) {
    commentText = readBodyFile(flags["comment-file"])
  } else if (typeof flags.comment === "string") {
    commentText = flags.comment
  } else if (flags.comment === true) {
    console.error(`Error: --comment requires a text value (or use --comment-file)`)
    process.exit(1)
  }
  if (commentText !== null) {
    const embed = `![${filename}](${uploadFile.assetUrl})`
    const body = commentText.trim().length > 0
      ? `${commentText.trim()}\n\n${embed}\n`
      : `${embed}\n`
    const commentResp = await client.createComment({ issueId: issue.id, body })
    const comment = await commentResp.comment
    commentUrl = comment?.url || null
  }

  if (flags.json) {
    console.log(
      JSON.stringify(
        {
          asset_url: uploadFile.assetUrl,
          comment_url: commentUrl,
          attachment_id: attachmentId,
          issue: issue.identifier,
          filename,
          size,
          content_type: contentType,
        },
        null,
        2
      )
    )
    return
  }

  console.log(`✓ Uploaded ${filename} to #${issue.identifier} (${(size / 1024).toFixed(1)} KB)`)
  console.log(`  Asset URL: ${uploadFile.assetUrl}`)
  if (commentUrl) console.log(`  Comment:   ${commentUrl}`)
  if (attachmentId) console.log(`  Attachment ID: ${attachmentId}`)
}

async function relateIssues(identifier, relatedIdentifier, flags) {
  const client = getLinearClient()
  const graphQLClient = client.client

  // Resolve both issues
  async function resolveIssueId(idOrKey) {
    if (idOrKey.includes("-")) {
      const [teamKey, issueNumber] = idOrKey.toUpperCase().split("-")
      const response = await graphQLClient.rawRequest(
        `query findIssue($teamKey: String!, $issueNumber: Float!) {
          issues(filter: { team: { key: { eq: $teamKey } }, number: { eq: $issueNumber } }) {
            nodes { id identifier }
          }
        }`,
        { teamKey, issueNumber: parseInt(issueNumber) }
      )
      const issue = response.data.issues.nodes[0]
      if (!issue) throw new Error(`Issue not found: ${idOrKey}`)
      return issue
    }
    return { id: idOrKey, identifier: idOrKey }
  }

  const issue = await resolveIssueId(identifier)
  const relatedIssue = await resolveIssueId(relatedIdentifier)
  const relationType = flags.type || "blocks"

  const validTypes = ["blocks", "duplicate", "related"]
  if (!validTypes.includes(relationType)) {
    console.error(`Error: Invalid relation type '${relationType}'. Must be one of: ${validTypes.join(", ")}`)
    process.exit(1)
  }

  const response = await graphQLClient.rawRequest(
    `mutation createRelation($issueId: String!, $relatedIssueId: String!, $type: IssueRelationType!) {
      issueRelationCreate(input: { issueId: $issueId, relatedIssueId: $relatedIssueId, type: $type }) {
        success
        issueRelation { id type }
      }
    }`,
    { issueId: issue.id, relatedIssueId: relatedIssue.id, type: relationType }
  )

  if (flags.json) {
    console.log(JSON.stringify(response.data, null, 2))
    return
  }

  if (response.data.issueRelationCreate.success) {
    console.log(`✓ Relation created: #${issue.identifier} ${relationType} #${relatedIssue.identifier}`)
  } else {
    console.error(`Error: Failed to create relation`)
    process.exit(1)
  }
}

// ---- Documents ----
// Linear "documents" are prose docs (specs, meeting notes, RFCs) stored
// alongside issues. Body is plain markdown in the `content` field.
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

async function listDocuments(flags) {
  const client = getLinearClient()
  const graphQLClient = client.client
  const limit = flags.limit ? parseInt(flags.limit, 10) : 50
  const response = await graphQLClient.rawRequest(
    `query listDocuments($first: Int!) {
      documents(first: $first, orderBy: updatedAt) {
        nodes {
          id title url updatedAt
          creator { displayName }
          project { name }
        }
      }
    }`,
    { first: limit }
  )
  const docs = response.data.documents.nodes
  if (flags.json) {
    console.log(JSON.stringify(docs, null, 2))
    return
  }
  console.log("Documents\n")
  for (const d of docs) {
    const date = new Date(d.updatedAt).toISOString().split("T")[0]
    const where = d.project?.name || "—"
    console.log(`[${date}] ${d.title || "(untitled)"}\t${where}\t#${d.id}`)
  }
}

async function viewDocument(idOrTitle, flags) {
  const client = getLinearClient()
  const graphQLClient = client.client
  const fields = `id title url content createdAt updatedAt creator { displayName } project { name }`
  let doc
  if (UUID_RE.test(idOrTitle)) {
    const response = await graphQLClient.rawRequest(
      `query getDocument($id: String!) { document(id: $id) { ${fields} } }`,
      { id: idOrTitle }
    )
    doc = response.data.document
  } else {
    // URL slug is NOT the UUID, so resolve a non-UUID arg by exact title.
    const response = await graphQLClient.rawRequest(
      `query findDocument($title: String!) {
        documents(filter: { title: { eq: $title } }, first: 1) { nodes { ${fields} } }
      }`,
      { title: idOrTitle }
    )
    doc = response.data.documents.nodes[0]
  }
  if (!doc) {
    console.error(`Error: Document not found: ${idOrTitle}`)
    process.exit(1)
  }
  if (flags.json) {
    console.log(JSON.stringify(doc, null, 2))
    return
  }
  console.log(`Document: ${doc.title || "(untitled)"}\n`)
  console.log(`URL:\t\t${doc.url}`)
  if (doc.project) console.log(`Project:\t${doc.project.name}`)
  console.log(`Creator:\t${doc.creator?.displayName || "Unknown"}`)
  console.log(`Created:\t${new Date(doc.createdAt).toISOString().split("T")[0]}`)
  console.log(`Updated:\t${new Date(doc.updatedAt).toISOString().split("T")[0]}`)
  console.log(`ID:\t\t${doc.id}`)
  if (doc.content) {
    console.log(`\n---\n`)
    console.log(doc.content)
  }
}

async function searchDocumentsCmd(term, flags) {
  const client = getLinearClient()
  const graphQLClient = client.client
  const response = await graphQLClient.rawRequest(
    `query searchDocs($term: String!) {
      searchDocuments(term: $term, first: 20) {
        nodes { id title url updatedAt project { name } }
      }
    }`,
    { term }
  )
  const docs = response.data.searchDocuments.nodes
  if (flags.json) {
    console.log(JSON.stringify(docs, null, 2))
    return
  }
  console.log(`Documents matching "${term}"\n`)
  for (const d of docs) {
    const date = new Date(d.updatedAt).toISOString().split("T")[0]
    const where = d.project?.name || "—"
    console.log(`[${date}] ${d.title || "(untitled)"}\t${where}\t#${d.id}`)
  }
}

async function createDocument(title, flags) {
  const client = getLinearClient()
  const graphQLClient = client.client

  // Linear's validator requires EXACTLY ONE anchor (the schema types them all
  // as optional, but the API rejects "none" and "more than one").
  const anchors = ["team", "project", "issue", "initiative", "cycle", "release"]
  const provided = anchors.filter((a) => flags[a])
  if (provided.length === 0) {
    console.error(`Error: a document needs exactly one anchor.
Pass one of: --team <id|key>, --project <id>, --issue <id-or-key>, --initiative <id>, --cycle <id>, --release <id>`)
    process.exit(1)
  }
  if (provided.length > 1) {
    console.error(`Error: only one anchor allowed, got: ${provided.map((a) => "--" + a).join(", ")}`)
    process.exit(1)
  }

  const input = { title }
  if (flags["content-file"]) {
    input.content = readBodyFile(flags["content-file"])
  } else if (typeof flags.content === "string") {
    input.content = flags.content
  }

  if (flags.team) {
    input.teamId = await resolveTeamId(client, flags.team)
  } else if (flags.project) {
    input.projectId = flags.project
  } else if (flags.issue) {
    const issue = await resolveIssueByIdentifier(client, flags.issue)
    input.issueId = issue.id
  } else if (flags.initiative) {
    input.initiativeId = flags.initiative
  } else if (flags.cycle) {
    input.cycleId = flags.cycle
  } else if (flags.release) {
    input.releaseId = flags.release
  }

  const response = await graphQLClient.rawRequest(
    `mutation createDocument($input: DocumentCreateInput!) {
      documentCreate(input: $input) {
        success
        document { id title url createdAt }
      }
    }`,
    { input }
  )
  const payload = response.data.documentCreate
  if (!payload?.success) {
    console.error("Error: Failed to create document")
    process.exit(1)
  }
  if (flags.json) {
    console.log(JSON.stringify(payload.document, null, 2))
    return
  }
  console.log(`✓ Document created: ${payload.document.title}`)
  console.log(`  URL: ${payload.document.url}`)
  console.log(`  ID:  ${payload.document.id}`)
}

// ---- Issue search (text + AI/semantic) ----
async function searchIssuesCmd(query, flags) {
  const client = getLinearClient()
  const graphQLClient = client.client
  const limit = flags.limit ? parseInt(flags.limit, 10) : 25

  if (flags.semantic) {
    // Linear's AI embedding search — spans issues, projects, docs, initiatives.
    const response = await graphQLClient.rawRequest(
      `query semantic($query: String!, $maxResults: Int!) {
        semanticSearch(query: $query, maxResults: $maxResults) {
          results {
            type
            issue { identifier title url state { name } }
            project { name url }
            document { title url }
            initiative { name url }
          }
        }
      }`,
      { query, maxResults: limit }
    )
    const results = response.data.semanticSearch.results
    if (flags.json) {
      console.log(JSON.stringify(results, null, 2))
      return
    }
    console.log(`Semantic results for "${query}"\n`)
    for (const r of results) {
      if (r.issue) console.log(`  [issue]      #${r.issue.identifier}\t${r.issue.title}\t(${r.issue.state?.name})`)
      else if (r.project) console.log(`  [project]    ${r.project.name}`)
      else if (r.document) console.log(`  [document]   ${r.document.title}`)
      else if (r.initiative) console.log(`  [initiative] ${r.initiative.name}`)
    }
    return
  }

  const teamId = flags.team ? await resolveTeamId(client, flags.team) : undefined
  const response = await graphQLClient.rawRequest(
    `query searchIssues($term: String!, $first: Int!, $teamId: String) {
      searchIssues(term: $term, first: $first, teamId: $teamId) {
        totalCount
        nodes { identifier title url state { name } assignee { name } }
      }
    }`,
    { term: query, first: limit, teamId }
  )
  const payload = response.data.searchIssues
  if (flags.json) {
    console.log(JSON.stringify(payload.nodes, null, 2))
    return
  }
  console.log(`Issues matching "${query}"  (${payload.totalCount} total)\n`)
  for (const i of payload.nodes) {
    console.log(`  #${i.identifier}\t${i.title}\t${i.state?.name}\t${i.assignee?.name || "Unassigned"}`)
  }
}

// ---- Cycles ----
function cycleStatus(c) {
  if (c.isActive) return "active"
  if (c.isFuture) return "future"
  if (c.isPast) return "past"
  return "—"
}

async function listCycles(teamKeyOrId, flags) {
  const client = getLinearClient()
  const graphQLClient = client.client
  const filter = {}
  if (teamKeyOrId) {
    const teamId = await resolveTeamId(client, teamKeyOrId)
    filter.team = { id: { eq: teamId } }
  }
  const limit = flags.limit ? parseInt(flags.limit, 10) : 20
  const response = await graphQLClient.rawRequest(
    `query listCycles($first: Int!, $filter: CycleFilter) {
      cycles(first: $first, filter: $filter, orderBy: updatedAt) {
        nodes {
          id number name startsAt endsAt progress
          isActive isFuture isPast
          team { key }
        }
      }
    }`,
    { first: limit, filter: Object.keys(filter).length ? filter : undefined }
  )
  const cycles = response.data.cycles.nodes
  if (flags.json) {
    console.log(JSON.stringify(cycles, null, 2))
    return
  }
  console.log("Cycles\n")
  for (const c of cycles) {
    const start = c.startsAt ? c.startsAt.split("T")[0] : "?"
    const end = c.endsAt ? c.endsAt.split("T")[0] : "?"
    const pct = c.progress != null ? `${Math.round(c.progress * 100)}%` : "—"
    const name = c.name || `Cycle ${c.number}`
    console.log(`  [${cycleStatus(c)}] (${c.team?.key}) ${name}\t${start} → ${end}\t${pct}\t#${c.id}`)
  }
}

async function viewCycle(idOrTeam, flags) {
  const client = getLinearClient()
  const graphQLClient = client.client
  const cycleFields = `
    id number name startsAt endsAt completedAt progress
    issues(first: 250) {
      nodes { estimate state { type } assignee { name } }
    }`

  let cycle
  if (UUID_RE.test(idOrTeam)) {
    const r = await graphQLClient.rawRequest(
      `query cyc($id: String!){ cycle(id: $id){ ${cycleFields} } }`,
      { id: idOrTeam }
    )
    cycle = r.data.cycle
  } else {
    // Treat the arg as a team key/id and use that team's ACTIVE cycle.
    const teamId = await resolveTeamId(client, idOrTeam)
    const r = await graphQLClient.rawRequest(
      `query teamCyc($id: String!){ team(id: $id){ key activeCycle{ ${cycleFields} } } }`,
      { id: teamId }
    )
    cycle = r.data.team?.activeCycle
    if (!cycle) {
      console.error(`Error: team '${idOrTeam}' has no active cycle`)
      process.exit(1)
    }
  }
  if (!cycle) {
    console.error(`Error: cycle not found: ${idOrTeam}`)
    process.exit(1)
  }

  // Aggregate throughput per assignee (done = state type 'completed').
  const byPerson = {}
  for (const issue of cycle.issues.nodes) {
    const who = issue.assignee?.name || "Unassigned"
    const done = issue.state?.type === "completed"
    const pts = issue.estimate || 0
    const p = (byPerson[who] = byPerson[who] || { total: 0, done: 0, pts: 0, ptsDone: 0 })
    p.total++
    p.pts += pts
    if (done) {
      p.done++
      p.ptsDone += pts
    }
  }

  if (flags.json) {
    console.log(JSON.stringify({ cycle: { id: cycle.id, number: cycle.number, name: cycle.name }, throughput: byPerson }, null, 2))
    return
  }

  const name = cycle.name || `Cycle ${cycle.number}`
  const start = cycle.startsAt ? cycle.startsAt.split("T")[0] : "?"
  const end = cycle.endsAt ? cycle.endsAt.split("T")[0] : "?"
  const overall = cycle.progress != null ? `${Math.round(cycle.progress * 100)}%` : "—"
  console.log(`Cycle: ${name}  (${start} → ${end})`)
  console.log(`Overall progress: ${overall}\n`)
  console.log(`Throughput by assignee:\n`)
  console.log(`  Assignee              Done/Total   Points (done/total)`)
  const rows = Object.entries(byPerson).sort((a, b) => b[1].done - a[1].done)
  for (const [who, p] of rows) {
    const col = who.padEnd(20).slice(0, 20)
    console.log(`  ${col}  ${String(p.done).padStart(3)}/${String(p.total).padEnd(4)}    ${p.ptsDone}/${p.pts}`)
  }
}

// ---- Comments + reactions ----
async function listComments(identifier, flags) {
  const client = getLinearClient()
  const graphQLClient = client.client
  let issue
  try {
    issue = await resolveIssueByIdentifier(client, identifier)
  } catch (e) {
    console.error(`Error: Issue not found: ${identifier}`)
    process.exit(1)
  }
  const r = await graphQLClient.rawRequest(
    `query issueComments($id: String!) {
      issue(id: $id) {
        identifier
        comments { nodes { id body createdAt user { name } } }
      }
    }`,
    { id: issue.id }
  )
  const comments = r.data.issue.comments.nodes
  if (flags.json) {
    console.log(JSON.stringify(comments, null, 2))
    return
  }
  if (comments.length === 0) {
    console.log(`No comments on #${r.data.issue.identifier}`)
    return
  }
  console.log(`Comments on #${r.data.issue.identifier}  (use the #id with 'comment react'):\n`)
  for (const c of comments) {
    const date = new Date(c.createdAt).toISOString().split("T")[0]
    const body = c.body.replace(/\n/g, " ").slice(0, 80)
    console.log(`  [${date}] ${c.user?.name}: ${body}`)
    console.log(`     #${c.id}`)
  }
}

async function reactToComment(commentId, emoji, flags) {
  const client = getLinearClient()
  const graphQLClient = client.client
  // Linear wants a shortcode name (e.g. "+1", "tada", "eyes") — tolerate :colons:.
  const clean = emoji.replace(/^:|:$/g, "")
  const r = await graphQLClient.rawRequest(
    `mutation react($commentId: String!, $emoji: String!) {
      reactionCreate(input: { commentId: $commentId, emoji: $emoji }) {
        success
        reaction { id emoji }
      }
    }`,
    { commentId, emoji: clean }
  )
  const payload = r.data.reactionCreate
  if (!payload?.success) {
    console.error("Error: Failed to add reaction")
    process.exit(1)
  }
  if (flags.json) {
    console.log(JSON.stringify(payload.reaction, null, 2))
    return
  }
  console.log(`✓ Reacted :${payload.reaction.emoji}: on comment ${commentId}`)
}

// ---- Utility: status, inbox, favorites ----
async function showStatus(flags) {
  const client = getLinearClient()
  const graphQLClient = client.client
  const r = await graphQLClient.rawRequest(
    `query status {
      viewer { name displayName email admin }
      rateLimitStatus { limits { type remainingAmount allowedAmount reset } }
    }`
  )
  if (flags.json) {
    console.log(JSON.stringify(r.data, null, 2))
    return
  }
  const v = r.data.viewer
  const limits = r.data.rateLimitStatus?.limits || []
  console.log(`User:\t${v.displayName || v.name} (${v.email})${v.admin ? "  [admin]" : ""}`)
  if (limits.length === 0) {
    console.log(`API:\t(no rate-limit data returned for this token)`)
  } else {
    console.log(`API budget (current window):`)
    for (const l of limits) {
      // reset is epoch-millis; show as readable UTC if numeric.
      const reset = /^\d+$/.test(String(l.reset))
        ? new Date(Number(l.reset)).toISOString().replace("T", " ").slice(0, 19) + " UTC"
        : l.reset
      console.log(`  ${l.type}\t${l.remainingAmount}/${l.allowedAmount} left\treset: ${reset}`)
    }
  }
}

async function showInbox(flags) {
  const client = getLinearClient()
  const graphQLClient = client.client
  const limit = flags.limit ? parseInt(flags.limit, 10) : 20
  // Notification is an interface; its common fields (title/subtitle/url/readAt)
  // are enough to render every subtype without inline fragments.
  const r = await graphQLClient.rawRequest(
    `query inbox($first: Int!) {
      notificationsUnreadCount
      notifications(first: $first) {
        nodes { id type title subtitle readAt url createdAt }
      }
    }`,
    { first: limit }
  )
  const unread = r.data.notificationsUnreadCount
  let nodes = r.data.notifications.nodes
  if (flags.unread) nodes = nodes.filter((n) => !n.readAt)
  if (flags.json) {
    console.log(JSON.stringify({ unread, notifications: nodes }, null, 2))
    return
  }
  console.log(`Inbox  (${unread} unread)\n`)
  for (const n of nodes) {
    const dot = n.readAt ? " " : "•"
    const date = new Date(n.createdAt).toISOString().split("T")[0]
    const sub = n.subtitle ? ` — ${n.subtitle}` : ""
    console.log(`  ${dot} [${date}] ${n.title || n.type}${sub}`)
  }
}

async function listFavorites(flags) {
  const client = getLinearClient()
  const graphQLClient = client.client
  const limit = flags.limit ? parseInt(flags.limit, 10) : 50
  const r = await graphQLClient.rawRequest(
    `query favs($first: Int!) {
      favorites(first: $first) { nodes { id type title url } }
    }`,
    { first: limit }
  )
  const favs = r.data.favorites.nodes
  if (flags.json) {
    console.log(JSON.stringify(favs, null, 2))
    return
  }
  console.log("Favorites\n")
  for (const f of favs) {
    console.log(`  [${f.type}]\t${f.title || "(untitled)"}`)
  }
}

async function main() {
  const { resource, action, args, flags } = parseArgs(process.argv)

  // Handle help flags
  if (flags.h || flags.help) {
    if (!resource) {
      showHelp()
      process.exit(0)
    }

    switch (resource) {
      case "user":
        showUserHelp()
        break
      case "team":
        showTeamHelp()
        break
      case "project":
        showProjectHelp()
        break
      case "document":
        showDocumentHelp()
        break
      case "cycle":
        showCycleHelp()
        break
      case "comment":
        showCommentHelp()
        break
      case "template":
        showTemplateHelp()
        break
      case "label":
        showLabelHelp()
        break
      case "issue":
        if (!action) {
          showIssueHelp()
        } else {
          switch (action) {
            case "list":
              showIssueListHelp()
              break
            case "view":
              showIssueViewHelp()
              break
            case "create":
              showIssueCreateHelp()
              break
            case "update":
              showIssueUpdateHelp()
              break
            case "delete":
              showIssueDeleteHelp()
              break
            case "comment":
              showIssueCommentHelp()
              break
            case "images":
              showIssueImagesHelp()
              break
            case "relate":
              showIssueRelateHelp()
              break
            case "upload":
              showIssueUploadHelp()
              break
            default:
              showIssueHelp()
          }
        }
        break
      default:
        showHelp()
    }
    process.exit(0)
  }

  try {
    // Route commands
    switch (resource) {
      case "user":
        if (action === "list") {
          await listUsers(flags)
        } else {
          console.error(`Error: Unknown action '${action}' for resource 'user'

Run 'linear-cli user --help' for usage`)
          process.exit(1)
        }
        break

      case "team":
        if (action === "list") {
          await listTeams(flags)
        } else if (action === "states") {
          await listTeamStates(args[0], flags)
        } else if (action === "labels") {
          await listTeamLabels(args[0], flags)
        } else {
          console.error(`Error: Unknown action '${action}' for resource 'team'

Run 'linear-cli team --help' for usage`)
          process.exit(1)
        }
        break

      case "template":
        if (action === "list") {
          await listTemplates(flags)
        } else if (action === "view") {
          if (args.length === 0) {
            console.error(`Error: Missing template ID

Run 'linear-cli template --help' for usage`)
            process.exit(1)
          }
          await viewTemplate(args[0], flags)
        } else {
          console.error(`Error: Unknown action '${action}' for resource 'template'

Run 'linear-cli template --help' for usage`)
          process.exit(1)
        }
        break

      case "label":
        if (action === "list") {
          await listTeamLabels(null, flags)
        } else {
          console.error(`Error: Unknown action '${action}' for resource 'label'

Run 'linear-cli label --help' for usage`)
          process.exit(1)
        }
        break

      case "project":
        if (action === "list") {
          await listProjects(flags)
        } else {
          console.error(`Error: Unknown action '${action}' for resource 'project'

Run 'linear-cli project --help' for usage`)
          process.exit(1)
        }
        break

      case "document":
        switch (action) {
          case "list":
            await listDocuments(flags)
            break
          case "view":
            if (args.length === 0) {
              console.error(`Error: Missing document id or title

Run 'linear-cli document --help' for usage`)
              process.exit(1)
            }
            await viewDocument(args.join(" "), flags)
            break
          case "search":
            if (args.length === 0) {
              console.error(`Error: Missing search term

Run 'linear-cli document --help' for usage`)
              process.exit(1)
            }
            await searchDocumentsCmd(args.join(" "), flags)
            break
          case "create":
            if (args.length === 0) {
              console.error(`Error: Missing document title

Run 'linear-cli document --help' for usage`)
              process.exit(1)
            }
            await createDocument(args.join(" "), flags)
            break
          default:
            console.error(`Error: Unknown action '${action}' for resource 'document'

Run 'linear-cli document --help' for usage`)
            process.exit(1)
        }
        break

      case "cycle":
        switch (action) {
          case "list":
            await listCycles(args[0], flags)
            break
          case "view":
            if (args.length === 0) {
              console.error(`Error: Missing cycle id or team key

Run 'linear-cli cycle --help' for usage`)
              process.exit(1)
            }
            await viewCycle(args[0], flags)
            break
          default:
            console.error(`Error: Unknown action '${action}' for resource 'cycle'

Run 'linear-cli cycle --help' for usage`)
            process.exit(1)
        }
        break

      case "comment":
        switch (action) {
          case "list":
            if (args.length === 0) {
              console.error(`Error: Missing issue id or key

Run 'linear-cli comment --help' for usage`)
              process.exit(1)
            }
            await listComments(args[0], flags)
            break
          case "react":
            if (args.length < 2) {
              console.error(`Error: Need a comment-id and an emoji

Run 'linear-cli comment --help' for usage`)
              process.exit(1)
            }
            await reactToComment(args[0], args[1], flags)
            break
          default:
            console.error(`Error: Unknown action '${action}' for resource 'comment'

Run 'linear-cli comment --help' for usage`)
            process.exit(1)
        }
        break

      case "issue":
        switch (action) {
          case "list":
            await listIssues(flags)
            break

          case "search":
            if (args.length === 0) {
              console.error(`Error: Missing search query

Run 'linear-cli issue --help' for usage`)
              process.exit(1)
            }
            await searchIssuesCmd(args.join(" "), flags)
            break

          case "view":
            if (args.length === 0) {
              console.error(`Error: Missing issue identifier

Run 'linear-cli issue view --help' for usage`)
              process.exit(1)
            }
            await getIssue(args[0], flags)
            break

          case "create":
            if (args.length === 0) {
              console.error(`Error: Missing issue title

Run 'linear-cli issue create --help' for usage`)
              process.exit(1)
            }
            await createIssue(args.join(" "), flags)
            break

          case "update":
            if (args.length === 0) {
              console.error(`Error: Missing issue identifier

Run 'linear-cli issue update --help' for usage`)
              process.exit(1)
            }
            await updateIssue(args[0], flags)
            break

          case "delete":
            if (args.length === 0) {
              console.error(`Error: Missing issue identifier

Run 'linear-cli issue delete --help' for usage`)
              process.exit(1)
            }
            await deleteIssue(args[0], flags)
            break

          case "comment":
            if (args.length < 2) {
              console.error(`Error: Missing required arguments

Run 'linear-cli issue comment --help' for usage`)
              process.exit(1)
            }
            await addComment(args[0], args.slice(1).join(" "), flags)
            break

          case "relate":
            if (args.length < 2) {
              console.error(`Error: Missing required arguments

Run 'linear-cli issue relate --help' for usage`)
              process.exit(1)
            }
            await relateIssues(args[0], args[1], flags)
            break

          case "images":
            if (args.length === 0) {
              console.error(`Error: Missing issue identifier

Run 'linear-cli issue images --help' for usage`)
              process.exit(1)
            }
            await getIssueImages(args[0], flags)
            break

          case "upload":
            if (args.length < 2) {
              console.error(`Error: Missing required arguments

Run 'linear-cli issue upload --help' for usage`)
              process.exit(1)
            }
            await uploadFileToIssue(args[0], args[1], flags)
            break

          default:
            if (action) {
              console.error(`Error: Unknown action '${action}' for resource 'issue'

Run 'linear-cli issue --help' for usage`)
            } else {
              console.error(`Error: Missing action for resource 'issue'

Run 'linear-cli issue --help' for usage`)
            }
            process.exit(1)
        }
        break

      case "status":
        await showStatus(flags)
        break

      case "inbox":
        await showInbox(flags)
        break

      case "favorites":
      case "favorite":
        await listFavorites(flags)
        break

      default:
        if (resource) {
          console.error(`Error: Unknown resource '${resource}'

Run 'linear-cli --help' for usage`)
          process.exit(1)
        } else {
          showHelp()
        }
    }
  } catch (error) {
    if (error.message?.includes("API key")) {
      console.error(`Error: Invalid LINEAR_API_KEY

Check your API key is valid: https://linear.app/settings/api`)
    } else {
      console.error(`Error: ${error.message || "Unknown error occurred"}`)
    }
    process.exit(1)
  }
}
main()
