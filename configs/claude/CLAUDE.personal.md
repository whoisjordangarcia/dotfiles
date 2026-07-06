<!--
  Personal-environment Claude instructions (overlay).

  This file is the PERSONAL overlay for ~/.claude/CLAUDE.md. script/claude/setup.sh
  appends it to the shared base (configs/claude/CLAUDE.md) when NOT in work mode,
  producing the single ~/.claude/CLAUDE.md that Claude reads. Edit it here OR
  edit ~/.claude/CLAUDE.md live and run `claude-sync` (script/claude/sync-claude.sh)
  to write your edits back here.

  NOTE: the cmux recipes below are macOS-only (cmux doesn't exist on personal
  Arch machines) — they're harmless there, the triggers just never fire.
-->

## "check diff" → open the diff in a new cmux pane with neovim Diffview

When I ask you to **check the diff** (or "show me the diff", "open the diff",
"let me see the diff", etc.), open it in a **new cmux pane running neovim's
Diffview** so I can review it visually. Do this instead of (or in addition to)
printing the diff in the chat.

Recipe (verified working — follow exactly):

1. Create a focused pane and capture its surface ref:
   ```bash
   OUT=$(cmux new-pane --direction right --focus true)
   SURF=$(echo "$OUT" | grep -oE 'surface:[0-9]+' | head -1)
   ```
2. Launch **plain** nvim in the repo whose diff I want (use the repo I'm
   currently working in / the session cwd's git root):
   ```bash
   cmux send-panel --panel "$SURF" "cd <repo-root> && nvim\n"
   ```
3. Wait ~3–4s for lazy.nvim + the UI to fully initialize:
   ```bash
   sleep 4
   ```
4. Trigger Diffview **interactively** (this is the `<leader>gd` mapping →
   `:DiffviewOpen`, which shows working-tree changes):
   ```bash
   cmux send-panel --panel "$SURF" ":DiffviewOpen\n"
   ```

### Why it must be done this way (don't "optimize" these away)

- **Do NOT use `nvim -c DiffviewOpen` / `nvim +DiffviewOpen`.** Running it at
  `VimEnter` fires before lazy.nvim finishes loading the plugin and before the
  UI is ready; diffview's async coroutine `raise`s and you get a
  `diffview/async.lua ... init_layout` error. Launch nvim first, let it load,
  then send `:DiffviewOpen` as an interactive command.
- **Use a focused, reasonably-sized pane.** Diffview builds a 2-window
  horizontal layout; a cramped split can fail in `diff_2_hor.lua`
  (`nvim_win_call`). `--focus true` and a normal split width avoid this.
- The pane inherits the workspace cwd, but explicitly `cd <repo-root>` so the
  diff is for the right repo.

Notes: my nvim uses diffview.nvim (`<leader>gd` = `:DiffviewOpen`,
`<leader>gq` = `:DiffviewClose`). `send-panel` escape sequences: `\n`/`\r` =
Enter, `\t` = Tab; `\x1b` = Esc.

## "import tmux into cmux" → run `cmux_import_tmux`

When I ask you to open/import all my tmux sessions as cmux workspaces, use the
`cmux_import_tmux` shell function (defined in my dotfiles at
`configs/zshrc/.zshrc-modules/.zshrc.functions`). It loops `cmux workspace
create --name <session> --command "tmux attach -t <session>"` over `tmux ls`,
so each tmux session becomes a cmux workspace **titled to match the session
name**. It's idempotent — sessions that already have a same-named workspace are
skipped — so it's safe to re-run.

cmux has **no native "import tmux" command**; this function is the supported
way. The one-off equivalent if the function isn't loaded:

```bash
tmux ls -F '#{session_name}' | while read -r s; do
  CMUX_QUIET=1 cmux workspace create --name "$s" --command "tmux attach -t $s"
done
```

Notes: `cmux new-workspace` is now an alias for `cmux workspace create`;
`--name` sets the workspace title at creation (no separate rename needed).

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
