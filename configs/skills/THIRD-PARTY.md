# Third-party skills (installed from skills.sh, not vendored here)

Everything in `configs/skills/` is a skill **I** wrote for this machine. Third-party skills are installed on demand
with [`skills`](https://skills.sh) (the `npx skills` CLI) so they stay current instead of rotting as a vendored copy:

```bash
bash script/skills/install.sh          # install everything in the manifest below, for every agent
bash script/skills/install.sh agent-browser vercel-labs/agent-browser   # or one at a time: <name> <source>
npx -y skills update -g -y             # refresh the installed ones
npx -y skills ls -g                    # what is installed, from where
npx -y skills find <query>             # find something new (interactive)
```

`script/skills/install.sh` runs `npx -y skills add <source> -g -a '*' --copy -y -s <name>`, which installs into every
agent directory the CLI knows (Claude Code, Codex, Cursor, OpenCode, Pi), so one command covers all four harnesses.
The farms under `~/.claude/skills`, `~/.agents/skills`, `~/.codex/skills`, `~/.cursor/skills` also carry the local
skills from this repo as symlinks (see `script/skills/setup.sh`); the CLI's installs are real directories beside them.

## Manifest

| Skill | skills.sh source | Why |
|---|---|---|
| `agent-browser` | `vercel-labs/agent-browser` | all browser automation (CDP, OAuth logins, testing) |
| `find-skills` | `vercel-labs/skills` | discovering/installing skills |
| `vercel-react-best-practices` | `vercel-labs/agent-skills` | React/Next.js performance (trythefit) |
| `vercel-composition-patterns` | `vercel-labs/agent-skills` | React composition patterns (trythefit) |
| `web-design-guidelines` | `vercel-labs/agent-skills` | UI review guidelines (trythefit) |
| `mobile-ios-design` | `wshobson/agents` | iOS HIG / SwiftUI reference |
| `gws-calendar`, `gws-docs`, `gws-sheets` | `googleworkspace/cli` | Google Workspace; the full generated set lives in `configs/gws/` and is refreshed with `gws generate-skills` |
| `reverse-engineer-anything` | REA's own skill (ships with the `rea` MCP) | reversing binaries with REA — re-pull from the REA install if it goes missing |

Sources are tracked with hashes in `configs/agents/.skill-lock.json`.

## Skills that were vendored here and are now parked

`~/.claude/skills-disabled/` holds the marketing/CRO/SEO/design/process/AI set (aso-audit, social-content,
copywriting, copy-editing, seo-audit, signup-flow-cro, paywall-upgrade-cro, analytics-tracking, mobile-ios-design,
design-shotgun, code-review-advanced, grill-with-docs, grilling, teach, domain-modeling, babysit, find-skills,
plan-ceo-review, office-hours, pre-commit-check, and the six `nest-*` work skills). They came from public
marketplaces whose upstream each was installed from, and nothing on this machine used them; when one is wanted,
find it with `npx skills find <query>` and install it rather than restoring a stale copy.

## Local skills (kept here on purpose)

`configs/skills/` holds only skills written for this machine: `win11-vm`, `things3` (remote, via the Mac mini),
`ida-vm`, `ralph-prd`, `daily-note`, `obsidian-vault`, `notes-cli` (Obsidian vault, Linux config path), plus
`gws-*`. Omarchy's `omarchy` and `diagnose-crash` are not here at all — they are symlinked from
`/usr/share/omarchy/default/agents/skills/`, so an Omarchy update lands on its own.

Keep a skill description to one line of purpose plus triggers: every description is in the context of every session,
and the whole set is ~8 KB.