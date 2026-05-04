---
name: obsidian-vault
description: Search, create, and manage notes in the user's Obsidian vault at ~/dev/notes (a git repo) with wikilinks and MOC index notes. Use when user wants to find, create, organize, or commit notes in their Obsidian vault.
---

# Obsidian Vault

## Vault location

`~/dev/notes/` — this is a **git repository**, so commit changes when the user asks (or when finishing a session of note edits).

## Folder layout

The vault uses numbered top-level folders, not a flat structure:

```
00 - Tasks
01 - Morning Brief
02 - Code
03 - Daily Notes        # daily-note skill writes here
04 - Recipes
05 - Excalidraw
06 - Remarkable Exports
09 - Templates          # see Daily Note.md, Weekly Review.md, etc.
10 - Meta
11 - Other
13 - Screenshots
14 - MOCs               # Maps of Content (index notes) — see list below
```

Place new notes in the folder that best matches their topic. Untyped/quick notes can sit at the vault root.

## Naming conventions

- **Title Case** for all note filenames (`Claude Code.md`, not `claude-code.md`)
- **MOCs** (Maps of Content) live in `14 - MOCs/` and aggregate links to related notes — Obsidian's idiomatic equivalent of "index" notes
- Date-prefixed notes use ISO format: `2026-03-12 open source projects.md`

## Linking

- Use Obsidian `[[wikilinks]]` syntax: `[[Note Title]]` (no `.md` extension)
- Add a "Related" section at the bottom of new notes linking to dependencies/MOCs
- MOCs are mostly just bulleted lists of `[[wikilinks]]`

### Current MOCs (link to these by name to auto-resolve in Obsidian)

When a new note touches one of these topics, add a `[[MOC Name]]` link in the Related section so Obsidian auto-creates the backlink graph edge:

- `[[Claude Code]]`
- `[[Cooking]]`
- `[[Health and Insurance]]`
- `[[Homelab]]`
- `[[Linux]]`
- `[[Porsche]]`

If a fitting MOC doesn't exist, create one in `14 - MOCs/` rather than scattering related notes without a hub.

## Templates

Reusable templates live in `09 - Templates/`:
- `Daily Note.md` — used by the daily-note skill
- `Weekly Review.md`
- `Template,Snippet.md` / `Template,ExampleTemplate.md`

Read the relevant template before creating a note of that type.

## Workflows

### Always pull before searching/reading

The vault syncs across devices via git only. Before searching, listing, or reading notes, pull the latest:

```bash
cd ~/dev/notes && git pull --rebase --autostash
```

This guarantees you're not answering from a stale local copy. Skip the pull only if you literally just pulled in this same session.

### Search for notes

```bash
# Filename search
find ~/dev/notes -name "*.md" -not -path "*/.git/*" | grep -i "keyword"

# Full-text search
grep -rl "keyword" ~/dev/notes --include="*.md" --exclude-dir=.git
```

Or use the Glob/Grep tools directly with `~/dev/notes` as the path.

### Create a new note

1. Pick the right folder (or vault root for untyped quick notes)
2. Use **Title Case** for the filename
3. If a template applies, read `09 - Templates/<Template>.md` first
4. Write the body
5. Add `[[wikilinks]]` to related notes / the relevant MOC at the bottom
6. If the note is significant, add a backlink from the matching MOC in `14 - MOCs/`

### Find backlinks to a note

```bash
grep -rl "\[\[Note Title\]\]" ~/dev/notes --include="*.md" --exclude-dir=.git
```

### List MOCs

```bash
ls ~/dev/notes/"14 - MOCs"/
```

### Commit and push vault changes

The vault syncs via **git** (not Obsidian Sync). After making note edits, commit and push so other devices pick them up:

```bash
cd ~/dev/notes && git add -A && git commit -m "notes: <short summary>" && git push
```

For a single new note, prefer `git add <path>` over `git add -A` to avoid sweeping in unrelated working-tree changes (Excalidraw autosaves, screenshots, etc.).
