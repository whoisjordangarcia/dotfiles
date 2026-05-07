---
name: things3
description: Query and manipulate the user's Things 3 task database via the local CLI at ~/dev/things3-cli. Use whenever the user asks about their Things tasks, Today list, Inbox, projects, things to buy, shopping list from Things, or wants to add/trash a Things to-do. Triggers include "what's in Things", "what's on my Today list", "things to buy", "what's in my inbox", "what shopping tasks do I have", "add this to Things", "trash this in Things".
---

# Things 3 CLI

Local CLI for the user's Things 3 database. SQLite reads are **read-only**; writes go through the Things URL scheme or AppleScript.

## Location & invocation

- Repo: `~/dev/things3-cli`
- Run from anywhere: `cd ~/dev/things3-cli && python3 -m things3_cli <subcommand>`
- DB lives at `~/Library/Group Containers/JLMPQHK86H.com.culturedcode.ThingsMac/ThingsData-*/Things Database.thingsdatabase/main.sqlite` (opened read-only).

## Read commands (safe, default)

| Command | What it does |
|---|---|
| `today` | Tasks scheduled for Today |
| `inbox` | Inbox to-dos |
| `summary` | Open/done counts grouped by Area |
| `projects` | Active projects with open-todo counts |
| `checklists --min N` | Tasks with at least N checklist items |

Add `--format json` for machine-readable output (default is markdown).

## Write commands (use only when user explicitly asks)

| Command | What it does |
|---|---|
| `add "Title" [--notes ...] [--when today\|tomorrow\|YYYY-MM-DD] [--deadline YYYY-MM-DD] [--tag X] [--list "Project"]` | Quick-add via URL scheme |
| `push --file spec.json` | Bulk-create from Things JSON spec (requires `THINGS_TOKEN` env var) |
| `show <inbox\|today\|upcoming\|anytime\|someday\|logbook\|item-id>` | Open a list/item in the Things app |
| `trash --title "Exact title"` (repeatable) or `--id UUID` | Move to-dos to Trash via AppleScript |

## Shopping / grocery agent — primary source

When the user asks about "shopping list", "things to buy", "groceries", what they need from the store, etc., the **canonical source** is the active **Groceries** project in Things:

- Active Groceries project UUID: `FMx42m3VnWN4uKjXZPXaiw`
- (There's a second project also titled `Groceries` at UUID `XZP1PnZ9yiFaxx7TH8T9d1` that's an old/archived list — **ignore it**. Always query by UUID, not title, to avoid hitting the wrong one.)

Pull the current grocery list:

```bash
cd ~/dev/things3-cli && python3 -c "
from things3_cli import db
with db.connect() as c:
    rows = c.execute('''
        SELECT title, notes FROM TMTask
        WHERE project = 'FMx42m3VnWN4uKjXZPXaiw'
          AND status = 0 AND trashed = 0
        ORDER BY title
    ''').fetchall()
    for r in rows:
        print('-', r['title'].strip(), ('— ' + r['notes']) if r['notes'] else '')
"
```

When generating a weekly meal plan / grocery list (see `~/dev/notes/CLAUDE.md`), **always pull this list first** and merge its items into the week's grocery list so nothing gets missed.

After items have been bought, mark them complete via the URL scheme. (No direct DB writes.)

## Bulk-adding items to Groceries with section headings

The Groceries project has 4 headings: **Protein**, **Produce**, **Pantry**, **Weekly Recurring** (matches the store-section ordering in `~/dev/notes/CLAUDE.md`). New grocery items should land under the right heading so shopping is a top-to-bottom walk.

### The right approach: URL scheme with `heading=` param

`things3-cli add` now supports `--heading "<name>"` (added 2026-05-03). Use it in a Python loop for bulk adds:

```bash
cd ~/dev/things3-cli && python3 -c "
from things3_cli import url_scheme
import time
batches = {
    'Protein':         ['item 1', 'item 2'],
    'Produce':         ['item 3'],
    'Pantry':          ['item 4'],
    'Weekly Recurring':['item 5'],
}
for h, items in batches.items():
    for it in items:
        url_scheme.add(it, list_name='Groceries', heading=h)
        time.sleep(0.08)  # tiny gap so Things doesn't drop URL events
"
```

### Critical gotchas (learned the hard way)

1. **Project name must match exactly.** The active Groceries project is now named **`Groceries`** (no trailing space, no dupes). If `list=Groceries` doesn't match, items silently fall into Inbox. Verify via `osascript -e 'tell application "Things3" to return name of every project'`.

2. **Things' heading-routing quirk.** When you pass `heading=Protein` along with `list=Groceries`, Things sets the item's `heading` field to the matching heading's UUID **but may leave the item's own `project` column NULL**. That's normal — Things displays items by heading parentage when heading is set. Don't panic if `t.project IS NULL`; query by `heading.project` instead.

3. **Verification query** (correct version that handles the heading quirk):

```bash
cd ~/dev/things3-cli && python3 -c "
from things3_cli import db
with db.connect() as c:
    rows = c.execute('''
        SELECT t.title, h.title AS heading
        FROM TMTask t
        JOIN TMTask h ON t.heading = h.uuid
        WHERE h.project = 'FMx42m3VnWN4uKjXZPXaiw'
          AND t.type = 0 AND t.status = 0 AND t.trashed = 0
        ORDER BY h.\"index\", t.\"index\"
    ''').fetchall()
    for r in rows: print('-', r['heading'], '|', r['title'])
"
```

### When to use the AppleScript fallback

If the active Groceries project ever has no headings (fresh project, or headings deleted), fall back to creating to-dos directly inside the project — Things AppleScript can't create or assign headings, only the URL scheme can. To create headings, the user must add them manually in the UI (`⌘L` to convert a line to a heading).

```bash
# AppleScript fallback — adds to project root (no heading)
cat <<'APPLESCRIPT' | osascript
tell application "Things3"
    set targetProject to project id "FMx42m3VnWN4uKjXZPXaiw"
    repeat with itemTitle in {"Item 1", "Item 2"}
        make new to do with properties {name:(itemTitle as string)} at end of to dos of targetProject
    end repeat
end tell
APPLESCRIPT
```

## Other "buy" / shopping items outside Groceries

Some shopping-style tasks live outside the Groceries project (e.g. in `Buy`, `House`, `Admin`). To find them all in one pass:

```bash
cd ~/dev/things3-cli && python3 -c "
from things3_cli import db
with db.connect() as c:
    rows = c.execute('''
        SELECT t.title, p.title AS proj, a.title AS area, t.notes
        FROM TMTask t
        LEFT JOIN TMTask p ON t.project = p.uuid
        LEFT JOIN TMArea a ON t.area = a.uuid
        WHERE t.status = 0 AND t.trashed = 0
          AND (
            p.title = 'Buy'
            OR lower(t.title) LIKE '%buy %'
            OR lower(t.title) LIKE '%order %'
            OR lower(t.title) LIKE '%purchase %'
          )
    ''').fetchall()
    for r in rows:
        print('-', r['title'], '|', r['proj'] or r['area'] or '')
"
```

## Schema cheat sheet

- `TMTask`: to-dos, projects, headings. `type`: 0=todo, 1=project, 2=heading. `status`: 0=incomplete, 2=canceled, 3=completed. `trashed`: 0/1.
- `TMChecklistItem`: checklist items, joined to `TMTask` via `task` column.
- `TMArea`: areas. `TMTask.area` references `TMArea.uuid`.
- `TMTag`, `TMTaskTag`, `TMAreaTag`: tag relationships.
- Dates are stored as **Cocoa epoch seconds** (since 2001-01-01 UTC). Use `db.cocoa_to_datetime(seconds)` to decode.

## Safety rules

- **Never** write directly to the SQLite DB. Mutations go through the URL scheme (`url_scheme.py`) or AppleScript (`applescript.py`).
- Don't dump large amounts of personal task content unprompted — start with counts/structure, then drill in.
- Redact secrets, credentials, medical and financial details if encountered in notes.
- Don't run `add`, `push`, or `trash` without an explicit user request.

## Common patterns

- "What's on my Today list?" → `python3 -m things3_cli today`
- "What's in my inbox?" → `python3 -m things3_cli inbox`
- "What shopping tasks do I have?" / "Things to buy?" → use the SQL snippet above
- "Add 'X' to Things for tomorrow" → `python3 -m things3_cli add "X" --when tomorrow`
- "What projects are active?" → `python3 -m things3_cli projects`
