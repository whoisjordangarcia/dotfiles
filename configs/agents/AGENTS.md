# Memory

Global instructions for every agent on a personal machine: the rules that always apply, and pointers to the rest.
Project rules belong in that project's `AGENTS.md` — not here.

## This file

- **`~/dev/dotfiles/configs/agents/AGENTS.md` is the personal memory; edit it there, never a copy** (work machines link
  `AGENTS.work.md`). `memory-sync` symlinks `~/.claude/CLAUDE.md` and `~/.config/opencode/AGENTS.md` to it. Why
  symlinks, and the OpenCode `instructions` dead end: the header of `~/dev/dotfiles/script/memory-sync.sh`.
- **Never add a `CLAUDE.md` or `CLAUDE.local.md` to a repo that relies on `AGENTS.md`** — it suppresses the project's
  `AGENTS.md` (tested on 2.1.287). Use `.claude/rules/` for extra per-project rules.

## This machine

- Its dotfiles profile is `DOT_SYSTEM` in `~/dev/dotfiles/.dotconfig`. Machine facts — hardware, display, clipboard,
  browser/CDP, VMs, MCP Code Mode — are in `~/dev/dotfiles/configs/agents/machines/<DOT_SYSTEM>.md`; read it when a
  task touches one of those, not before. No file for the profile means nothing machine-specific is recorded.

## Web search

- One `websearch` per question; each call returns ~8 results — read them all before deciding.
- Never repeat a query you already ran; change it substantially or answer with what you have.
- At most 3 searches per user message, then answer (say what is still unknown instead of searching again).
- Search the terms the user actually used, not build numbers or names you invented.

## Vault

- `~/dev/notes` — `rg` is the fast path; the `obsidian` skill covers daily notes, note hygiene and the Obsidian CLI.
  The vault's own `AGENTS.md` is the rulebook (lookup ladder, tags, routing, commit rules).
