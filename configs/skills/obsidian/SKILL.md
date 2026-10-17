---
name: obsidian
description: "Work with the Obsidian vault at ~/dev/notes (a git repo): create/append/show today's daily note, find or organise notes with wikilinks and MOCs, commit them, and answer semantic questions (tasks, tags, backlinks, frontmatter, orphans) through the official obsidian CLI. Triggers: vault, daily note, today's note, jot this down, save to vault, obsidian, obsidian cli, find a note, note links, list all tasks, tags, backlinks, orphan notes, frontmatter, ~/dev/notes."
user-invocable: true
---

# Obsidian vault (~/dev/notes)

One skill for the whole vault: daily notes, finding and creating notes, and the semantic layer Obsidian's CLI adds.

## Rules first — they are not here

**`~/dev/notes/AGENTS.md` is the rulebook**: the lookup ladder (filenames → git log → MOCs → `rg`), the closed tag
vocabulary, content routing, commit style (**never `git pull`, `git push` or `git rebase`** — a timer owns the remote),
and the link rules. Read it before doing anything non-trivial here; this file is the mechanics.

Two things it will tell you that are easy to get wrong:

- **Never `git pull`/`push`/`rebase`.** Commit locally with a terse message and stop.
- **Structural questions go to Obsidian's index, not `rg`** (tags, backlinks, orphans, link resolution) — see the CLI
  section below.

## Daily notes

Location `03 - Daily Notes/YYYY-MM-DD <topic-slug>.md` (plain `YYYY-MM-DD.md` if the topic isn't known yet — rename it
once it is). Always check for today's note first and **append**; never overwrite, never create a second note when one
fits.

```bash
ls ~/dev/notes/"03 - Daily Notes"/ | grep "^$(date +%Y-%m-%d)"
```

New note body — **no H1** (Obsidian renders the filename as the title, so a matching H1 shows twice):

```markdown
## Notes

- what was worked on, commands worth keeping, ideas, open questions

---

## Tasks

- [ ] follow-ups
```

Record what was worked on, commands/snippets worth keeping, ideas (flag big ones with `#idea`), tasks. Backlink
liberally: existing notes, concepts that don't have one yet, and the relevant MOC. When the user only asks to *see*
today's note, read it and show it verbatim — don't edit, and don't create an empty one just to display.

## Finding and creating notes

```bash
# filenames are the index — try this before anything heavier
ls ~/dev/notes/"03 - Daily Notes"/*keyword*
# then full text, excluding the auto-generated Morning Brief
rg -il 'keyword' ~/dev/notes --glob '!01 - Morning Brief/**'
# recent history, zero file reads
git -C ~/dev/notes log --oneline -30
```

- **Update an existing note rather than creating a near-duplicate** — search first.
- New note: pick the folder by topic (numbered folders, root is config only), **Title Case** the filename unless it's a
  dated note, read `09 - Templates/<Template>.md` if one applies, add `[[wikilinks]]` and a link from the matching MOC
  in `14 - MOCs/`.
- MOCs: `Linux`, `Claude Code`, `Homelab`, `Handhelds`, `Home Assistant`, `Cooking`, `Porsche`, `Health and Insurance`,
  `Projects`. No fitting MOC? create one rather than scattering unlinked notes.
- `[[Alias]]` does **not** resolve through a frontmatter alias — use the piped form `[[Real Note|other spelling]]`.
  Never link a `~/.claude` memory filename; those can never resolve.

## The obsidian CLI (semantic layer)

`obsidian` drives a **running** Obsidian, so it can answer what text search can't. Enabled via `"cli": true` in
`~/.config/obsidian/obsidian.json`.

| Question | Tool |
|---|---|
| all open tasks across the vault | `obsidian tasks` |
| what links to this note | `obsidian backlinks file="X"` |
| tags and counts | `obsidian tags` |
| orphans / dead ends | `obsidian orphans` / `obsidian deadends` |
| frontmatter properties | `obsidian properties` |
| append to today's note | `obsidian daily:append content="..."` |
| arbitrary query over the metadata cache (Dataview) | `obsidian eval code="..."` |

Without the app (headless, cron, another machine) use the checked-in helper instead:
`python3 "~/dev/notes/02 - Code/vault-index.py" <tags|tagged|backlinks|links|unresolved|moc-gaps>` — same parsing
rules, no app, ~0.2 s for the vault. `selftest` after any edit.

**Gotchas:** args are `key=value`, never `--flags` (`obsidian search query="foo" limit=5`); **never pipe to
`head`/`tail`** (SIGPIPE hang — use `limit=N`); `file=` resolves by name like a wikilink, `path=` is exact.

## Committing

```bash
git -C ~/dev/notes add <path>            # prefer the path over `add -A`
git -C ~/dev/notes commit -m "Add <thing> <date>"
```

Terse, sentence-case, matching the log. That's all — a timer syncs the remote. See `AGENTS.md` for the rest.

## Related

`10 - Meta/Obsidian Workflow.md` · `10 - Meta/Vault Tooling Decision.md` ·
`10 - Meta/Vault agent conventions reference.md` (benchmarks behind the lookup ladder) ·
`02 - Code/vault index gap queries.md`