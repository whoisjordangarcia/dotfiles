---
name: things3
description: "Query and manage Things 3 tasks. The database is on the M4 Mac mini, so every call is an ssh to `macmini` running things3-cli there. Triggers: Things tasks, Today list, Inbox, projects, things to buy, shopping list, add/trash a to-do."
---

# Things 3 CLI (remote, on the Mac mini)

The Things database and the CLI are on the **Mac mini**, reachable over ssh as `macmini` (alias `falcon9`,
`jordangarcia@Jordans-Mac-mini.local`). Nothing is installed for this locally: there is no `~/dev/things3-cli` here,
and the Things URL scheme / AppleScript only work on the Mac itself — which is fine, because the CLI runs there.

## Invocation

Everything runs over ssh; keep commands read-only unless the user asked for a change:

```bash
ssh macmini 'cd ~/dev/things3-cli && python3 -m things3_cli <command> [args]'
```

- Read: `today`, `inbox`, `summary`, `projects`, `checklists`, `headings <project>`, `project <project>`,
  `under <heading>`, `show <list|id>`. `--format json` is a **global** flag, so it goes before the command
  (`python3 -m things3_cli --format json today`); the default output is markdown.
- Write (only on an explicit request): `add "Title" --when tomorrow --list "Project" --heading "Heading"` (URL
  scheme), `trash --title "Exact title"` (AppleScript, exact match), `complete <id>`.
- `move`, `update` and bulk `push` need `THINGS_TOKEN` on the mini; non-loopback binds of `serve` need
  `THINGS_API_TOKEN`.
- `--heading`/`--list` must name an **existing** heading or project — the URL scheme cannot create them, so list the
  project's headings first (`headings <project>`); project UUIDs are the stable way to target one.

## Ground rules

- The Things database is read-only to us: never mutate `main.sqlite` tables, even small fixes. Writes go through the
  URL scheme or AppleScript, which is what the CLI's write commands do.
- Don't `add`/`trash`/`push` without an explicit request in the conversation.
- The mini's `~/dev/things3-cli/AGENTS.md` is the authority on the data model (`TMTask`, `TMArea`, `TMChecklistItem`,
  `TMTag`, `TMTaskTag`/`TMAreaTag`) and on the database path
  (`~/Library/Group Containers/JLMPQHK86H.com.culturedcode.ThingsMac/ThingsData-*/Things Database.thingsdatabase/main.sqlite`).
  Read it over ssh when a query needs schema detail.