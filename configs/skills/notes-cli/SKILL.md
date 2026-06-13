---
name: notes-cli
description: "Use when querying the Obsidian vault at ~/dev/notes through the official `obsidian` CLI — for semantic queries that plain file tools can't answer: tasks across notes, tags, backlinks, aliases, properties/frontmatter, orphans/deadends, daily-note ops, or scripting Obsidian via eval. Triggers on: obsidian cli, obsidian command, list all tasks, list tags, backlinks, orphan notes, query frontmatter, daily note append from terminal, obsidian eval."
user-invocable: true
---

# notes-cli

The **official Obsidian CLI** (`obsidian`, bundled with the Obsidian cask). It drives a *running* Obsidian instance, so it can answer **semantic** questions about the vault — tasks, tags, backlinks, frontmatter, link graph — that `rg`/`Glob` can't, because those derive from Obsidian's metadata cache, not raw text.

For plain text/content search and file creation, prefer native tools — see [[obsidian-vault]]. This skill is for the semantic layer. (Background: the vault tooling decision lives at `10 - Meta/Vault Tooling Decision.md`.)

## Prerequisites & gotchas (read first — these are the things that bite)

1. **Obsidian app must be running.** The CLI talks to the live app. No app → commands fail.
2. **The CLI must be enabled.** If you see `Command line interface is not enabled`, the `"cli": true` flag is off. Fix: enable Settings → General → Advanced → "Command line interface", or set it in `~/Library/Application Support/obsidian/obsidian.json`. (On a fresh machine this is done automatically by `dotfiles/script/notes/setup.sh`.)
3. **Args are `key=value`, NOT `--flags`.** It's `obsidian search query="foo" limit=5`, never `--query`. Quote values with spaces: `name="My Note"`.
4. **Do NOT pipe to `head`/`tail`.** The CLI gets SIGPIPE and hangs. Use the built-in `limit=N` or redirect to a file and read that.
5. **`file=` resolves by name (like a wikilink); `path=` is exact** (`folder/note.md`). Most commands default to the active file if both are omitted.

## When to use the CLI vs native tools

| Question | Tool |
|---|---|
| "Find every note mentioning X" (text) | `rg` (faster, no app needed) |
| "List all open tasks across the vault" | `obsidian tasks` |
| "What links to this note?" | `obsidian backlinks file="X"` |
| "All tags / tag counts" | `obsidian tags` |
| "Notes with no incoming/outgoing links" | `obsidian orphans` / `obsidian deadends` |
| "Read/query frontmatter properties" | `obsidian properties`, `property:read` |
| "Append to today's daily note" | `obsidian daily:append content="..."` |
| "Arbitrary query over the metadata cache / Dataview" | `obsidian eval code="..."` |

## Quick reference (verified commands)

```bash
# --- Search (returns stdout; format=text|json) ---
obsidian search query="cigna" format=json        # -> JSON array of file paths
obsidian search:context query="tooling" limit=5  # matches with surrounding lines

# --- Tasks ---
obsidian tasks                                    # all "- [ ]"/"- [x]" across the vault

# --- Tags / properties (frontmatter) ---
obsidian tags                                     # list tags
obsidian tags total                               # just the count (e.g. 144)
obsidian properties                               # list frontmatter properties
obsidian property:read file="My Note" key=rating

# --- Link graph ---
obsidian backlinks file="Vault Tooling Decision" format=json
obsidian links file="My Note"                     # outgoing links
obsidian orphans                                  # no incoming links
obsidian deadends                                 # no outgoing links
obsidian unresolved                               # dangling [[links]]
obsidian aliases                                  # all aliases

# --- Daily notes (match CLAUDE.md daily-note workflow) ---
obsidian daily:path                               # -> 2026-06-12.md
obsidian daily:read
obsidian daily:append content="- new thought"     # \n for newline, \t for tab

# --- Files / vault info ---
obsidian files                                    # list files
obsidian read file="My Note"
obsidian vault                                    # vault info
obsidian wordcount

# --- Power tool: run JS inside Obsidian (reaches app, metadata cache, Dataview) ---
obsidian eval code="app.vault.getMarkdownFiles().length"   # -> => 449
```

Run `obsidian help` for the full command list (90+ commands: bases, bookmarks, history/sync, plugins, themes, dev:* DevTools, etc.). Each command lists its own params in `obsidian help`.

## Scripting note

Because `search ... format=json`, `backlinks ... format=json`, and `eval` print to stdout, they compose into pipelines — just avoid `head`/`tail` (gotcha #4). Redirect to a temp file and read it when you need to truncate:

```bash
obsidian tasks > /tmp/tasks.txt   # then read the file
```

## Common mistakes

- Using `--flag` syntax → returns "Missing required parameter". Use `key=value`.
- Piping to `head` and the terminal hangs → it's SIGPIPE; use `limit=` or a file.
- "Command line interface is not enabled" → app setting / `cli:true` not set (prereq #2).
- Empty results when the app isn't running → start Obsidian first.
