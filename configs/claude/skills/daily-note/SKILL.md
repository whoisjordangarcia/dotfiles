---
name: daily-note
description: "Use whenever the user mentions the vault, daily note, today's notes, or ~/dev/notes — for creating, appending to, OR retrieving/showing today's Obsidian daily note. Triggers on: vault, daily note, daily-note, today's note, show me today's note, what's in my note today, read my daily note, add to my notes, add to notes for today, jot this down, note this, save to vault, put in my notes, ~/dev/notes."
user-invocable: true
---

# Daily Note

Create or append to today's daily note in the Obsidian vault.

---

## The Job

1. Determine today's date using the system/current date
2. Check if a note for today already exists in `03 - Daily Notes/`
3. If it exists, read it and **append** new content under the appropriate section
4. If it doesn't exist, create a new note using the template below

---

## File Location

**Always** place daily notes in:

```
/Users/nest/dev/notes/03 - Daily Notes/
```

## Naming Convention

```
YYYY-MM-DD <topic-slug>.md
```

- Date comes first, always `YYYY-MM-DD` format
- Topic slug is lowercase, hyphenated, and describes the subject
- If the user doesn't specify a topic, use just the date: `YYYY-MM-DD.md`
- Examples: `2026-02-18 nest-ideas.md`, `2026-02-18.md`

## Finding Today's Note

Before creating a new file, **always check** if a note for today already exists:

```bash
ls "/Users/nest/dev/notes/03 - Daily Notes/" | grep "^$(date +%Y-%m-%d)"
```

- If a matching file exists, **read it and append** new content to the relevant section
- If multiple files exist for today with different topics, ask the user which one to use or create a new topic-specific note
- **Never overwrite** an existing note

## Template (New Notes Only)

```markdown
# <Title>

## Notes

<content goes here>

---

## Tasks

- [ ] <task items if applicable>
```

## Retrieving / Showing Today's Note

When the user asks to see, read, show, or review today's daily note:

1. Find today's file in `/Users/nest/dev/notes/03 - Daily Notes/` matching `YYYY-MM-DD*.md`
2. If multiple files exist for today (different topic slugs), list them and ask which to show — or show all if the user said "everything for today"
3. Read the file and present its contents to the user verbatim (preserve markdown formatting)
4. Do NOT edit or append anything when the user is only asking to view
5. If no note exists for today, say so plainly — don't create an empty one just to display it

## Appending to Existing Notes

When appending to an existing note:
- Add new content under `## Notes` section, after existing content
- Add new tasks under `## Tasks` section, after existing items
- Use `---` to separate distinct entries if needed
- Preserve all existing content exactly as-is

## Important Rules

- **Always use the current date** — never hardcode or assume the date
- **Always check for existing notes first** — append, don't duplicate
- **Never delete or overwrite** existing note content
- Use bullet points and checklists (`- [ ]`) for actionable items
