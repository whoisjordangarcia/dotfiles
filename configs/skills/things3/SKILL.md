---
name: things3
description: "Query and manage Things 3 tasks via things3-cli. The database lives on the M4 Mac mini: run the CLI locally there, ssh to it from anywhere else. Triggers: Things tasks, Today list, Inbox, projects, things to buy, shopping list, groceries, add/trash a to-do."
---

# Things 3 CLI

The Things database and `~/dev/things3-cli` live on the **Mac mini** (`Jordans-Mac-mini.local`). The URL scheme and
AppleScript only work on that Mac, so the CLI always runs there.

## Invocation

Check `hostname` first:

```bash
# On the Mac mini (hostname = Jordans-Mac-mini.local): run locally
cd ~/dev/things3-cli && python3 -m things3_cli <command> [args]

# Anywhere else: ssh in (the `macmini` alias is NOT defined on every box; the .local name is)
ssh jordangarcia@Jordans-Mac-mini.local 'cd ~/dev/things3-cli && python3 -m things3_cli <command> [args]'
```

For a non-ssh client (Home Assistant, phone, a container), use the `things3-api` skill instead.

- Read: `today`, `inbox`, `summary`, `projects`, `checklists`, `headings [--project <uuid|title>]`,
  `project <uuid|title>`, `under <heading>`, `show <list|id>`. `--format json` is a **global** flag, so it goes
  before the command (`python3 -m things3_cli --format json today`); the default output is markdown.
- Write (only on an explicit request): `add "Title" --when tomorrow --list "Project" --heading "Heading"` (URL
  scheme), `trash --title "Exact title"` (repeatable, AppleScript, exact match) or `--id UUID`, `complete <id>`.
- `move`, `update` and bulk `push` need `THINGS_TOKEN`; non-loopback binds of `serve` need `THINGS_API_TOKEN`.
- `--heading`/`--list` must name an **existing** heading or project. The URL scheme can't create them, and a
  non-matching `--list` silently drops the item into the Inbox. List them first with `headings --project <uuid>`.

## Groceries (canonical shopping list)

- Project UUID **`FMx42m3VnWN4uKjXZPXaiw`**. A stale duplicate also titled `Groceries` (`XZP1PnZ9yiFaxx7TH8T9d1`)
  exists, so always target by UUID: `project FMx42m3VnWN4uKjXZPXaiw`.
- Store-section headings: **Protein**, **Produce**, **Pantry**, **Weekly Recurring**. Route each new item to its
  section. Ignore the non-shopping headings (`External`, etc.).
- Heading quirk: an item added with `--heading` gets `heading` set but may have a NULL `project` column. Query
  through the heading (`JOIN TMTask h ON t.heading = h.uuid WHERE h.project = '<uuid>'`), not `t.project`.
- When planning meals, pull this list first and merge it into the week's groceries.

## Ground rules

- The database is read-only to us: never write to `main.sqlite`. Writes go through the URL scheme or AppleScript,
  which is what the CLI's write commands do.
- Don't `add`/`trash`/`push` without an explicit request in the conversation.
- `~/dev/things3-cli/AGENTS.md` is the authority on the data model (`TMTask` type 0=todo/1=project/2=heading,
  status 0=open/2=canceled/3=done; `TMArea`, `TMChecklistItem`, `TMTag`) and the database path. Read it when a
  query needs schema detail.
