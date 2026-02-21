---
name: daily-note
description: "Use when creating a daily note, adding notes for today, or jotting down ideas. Triggers on: daily note, create a note, add to today's note, jot this down, note this."
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
