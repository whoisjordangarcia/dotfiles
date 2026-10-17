# Memory

Global instructions for every agent on this machine: rules that always apply, what this machine is, and where the
reference material lives. Project rules belong in that project's `AGENTS.md` — not here.

## This file

- **`~/dev/dotfiles/configs/agents/AGENTS.md` is the single global memory** — one file, git-tracked, the only one to
  edit. `memory-sync` (`~/.local/bin/memory-sync`, mirrored at `script/memory-sync.sh`) points every harness at it:
  `~/.claude/CLAUDE.md` and `~/.config/opencode/AGENTS.md` are both **symlinks** to it — each harness fixes the
  name it looks for (Claude's user scope is `CLAUDE.md` and nothing else, `~/.claude/AGENTS.md` is never read;
  OpenCode's global is `AGENTS.md` in its config dir), so each gets a link to the same file. Nothing is copied, so
  nothing can drift; `--check` just reports broken links. Don't "fix" this by pointing OpenCode at this file with
  an `instructions` entry in `opencode.json` — that key is in the published schema but this build ignores it.
  Projects are `AGENTS.md`, which Claude Code loads by default (v2.1.277+). Tested on 2.1.287: a project
  `CLAUDE.md` or `CLAUDE.local.md` **suppresses** the project's `AGENTS.md` — the documented
  `pluginConfigs."cc-plugin-agents-md@builtin".options.instructionFiles = "claude-md-and-agents-md"` override is
  ignored by that build under both plugin IDs (and top-level `claudeMd` in user settings is a documented no-op). So
  never add a `CLAUDE.md`/`CLAUDE.local.md` to a repo that relies on `AGENTS.md`; use `.claude/rules/` for extra
  per-project rules. `AGENTS.local.md` and `~/.claude/AGENTS.md` are read by nobody.
- Reference material is **not** in this file: this machine's hardware and browser/CDP recipe in
  `~/dev/notes/02 - Code/MacBook Pro 15 (omarchy) machine reference.md`, and the memory pipeline, skill farms and
  harness quirks in `~/dev/notes/10 - Meta/Agent memory and skills setup.md`. Read a note when a task touches it.

## Web search

- One `websearch` per question; each call returns ~8 results — read them all before deciding.
- Never repeat a query you already ran; change it substantially or answer with what you have.
- At most 3 searches per user message, then answer (say what is still unknown instead of searching again).
- Search the terms the user actually used, not build numbers or names you invented.

## MCP tools in Code Mode (`execute`)

- `ida_*` is called directly; `rea` and other big servers live inside `execute`
  (`const r = await tools.rea.open_binary({ path: "/abs/path" }); return r;`).
- A `tools.*` call returns the payload itself: `return r`, never `r.result` (undefined → null).
- Unsure of a tool's params: `return await search({ query: "binary_overview", namespace: "rea" })` — don't guess and
  don't grep node_modules or websearch for docs. `rea` needs `open_binary` first; `ida` needs `idb_open`
  (Windows path inside the VM), see the `ida-vm` skill.

## This machine (grasshopper / `omarchy`)

MacBook Pro 15,1 (2018, T2) laptop running Omarchy Arch; dual GPU (Intel drives the panel, AMD 560X drives external
output), Hyprland/Wayland, dotfiles in `~/dev/dotfiles` symlinked into `~/.config`.

- **Details live in notes, not here.** Hardware tables, the T2 USB-C Alt Mode dead end, the macOS+Linux CDP/browser
  recipe, remote Things 3 on the macmini and the other machines:
  `~/dev/notes/02 - Code/MacBook Pro 15 (omarchy) machine reference.md`. Memory pipeline, skill farms and harness
  quirks: `~/dev/notes/10 - Meta/Agent memory and skills setup.md`. Read a note when the task touches it, not before.
- `sudo` or anything this shell can't run: put it on the clipboard with `wl-copy` rather than only printing it.
- `opencode` on `PATH` is OpenCode **V1**; the V2 config (`~/.config/opencode/opencode.json`) needs **`opencode2`**.
- Vault: `~/dev/notes` — `rg` is the fast path; the `obsidian` skill covers daily notes, note hygiene and the
  Obsidian CLI. The vault's own `AGENTS.md` is the rulebook (lookup ladder, tags, routing, commit rules).
