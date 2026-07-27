<!--
  Personal-environment Claude instructions (overlay).

  This file is the PERSONAL overlay for ~/.claude/CLAUDE.md. script/claude/setup.sh
  appends it to the shared base (configs/claude/CLAUDE.md) when NOT in work mode,
  producing the single ~/.claude/CLAUDE.md that Claude reads. Edit it here OR
  edit ~/.claude/CLAUDE.md live and run `claude-sync` (script/claude/sync-claude.sh)
  to write your edits back here.

-->

## Browser automation on this Mac → drive Brave via CDP (non-headless)

The "Agent Browser" Chrome profile does **not** exist on this Mac (only
Chrome's `Default (Personal)`). When a task needs my logged-in sessions
(Facebook Marketplace, shopping, etc.), attach agent-browser to my real
**Brave** browser over CDP instead. This is inherently non-headless — I can
watch it work in my actual browser window.

Recipe (verified working 2026-07-03):

1. Brave doesn't listen on a CDP port by default. Quit it gracefully and
   relaunch with debugging enabled (tabs restore automatically):
   ```bash
   osascript -e 'quit app "Brave Browser"'
   sleep 3
   nohup "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" \
     --remote-debugging-port=9222 --restore-last-session >/dev/null 2>&1 &
   sleep 5
   curl -s http://127.0.0.1:9222/json/version   # confirm CDP is up
   ```
2. Drive it with `agent-browser --cdp 9222 ...`. Open work in a **new tab**
   (`tab new <url>`) so my existing tabs aren't clobbered.
3. Skip screenshots — read pages with `snapshot -i` or `eval` on the DOM
   (see agent-browser memory note).

Gotchas (don't re-debug these):

- **"Chrome profile 'Agent Browser' not found" even with `--cdp`** → a stale
  agent-browser daemon is holding the dead profile config. Fix:
  `agent-browser close --all`, kill the pid in `~/.agent-browser/default.pid`,
  remove `~/.agent-browser/default.{sock,pid}`, retry.
- Brave (v150) does **not** block `--remote-debugging-port` on the default
  profile the way Chrome 136+ does — attaching to the real profile works.
- A normal quit + reopen of Brave later closes the debug port (back to stock).

## Things 3 tasks (~/dev/things3-cli) → use the `things3` skill

Tasks live in Things 3. For anything task-related — Today, inbox, "things to
buy", add/trash a to-do — use the **`things3` skill** (full reference, schema,
grocery patterns; auto-triggers on task keywords). Run commands from
`~/dev/things3-cli`. Essentials the skill assumes you know:

- Read: `python3 -m things3_cli today|inbox|summary|projects` (`--format json`).
- Add: `add "Title" --when tomorrow --list "Project" --heading "Section"` — `--heading` must name an **existing** heading (URL scheme can't create them).
- Remove: `trash --title "Exact title"` (repeatable) or `--id UUID`.
- Groceries = canonical shopping list: project UUID `FMx42m3VnWN4uKjXZPXaiw` (query by UUID — a stale dupe exists), headings Protein/Produce/Pantry/Weekly Recurring. `THINGS_TOKEN` is set for bulk `push`.
- **Never** write the SQLite DB directly; don't `add`/`trash`/`push` without an explicit request.

<!-- After editing this section live, run `claude-sync` to persist it to the dotfiles overlay. -->
