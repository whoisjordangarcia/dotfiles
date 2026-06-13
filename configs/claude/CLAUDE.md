# Global instructions

## Working with my Obsidian notes (~/dev/notes)

The vault is plain markdown in a git repo. When a task involves my notes, pick the right tool:

- **Create / append daily notes** → use the `daily-note` skill.
- **Find, create, organize, or commit notes** (text search, file ops, wikilinks, MOCs) → use the `obsidian-vault` skill. Plain text search is fastest with `rg`/`Glob` — no app needed.
- **Semantic queries** — tasks across notes, tags, backlinks, frontmatter/properties, orphans, link graph, or scripting Obsidian via `eval` → use the `notes-cli` skill (the official `obsidian` CLI). Requires the Obsidian app to be running.

Rule of thumb: **text matching → native file tools; questions about Obsidian's metadata (tasks/tags/links/frontmatter) → `notes-cli`.** See `~/dev/notes/10 - Meta/Vault Tooling Decision.md` for the why.
