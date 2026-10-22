---
name: dotfiles
description: "Use when changing or applying the user's dotfiles (~/dev/dotfiles): editing a config, adding a macOS default, adding/re-running a module (component), checking which modules this machine installs, personal vs work setup, or running the dotfiles tests. Triggers: dotfiles, dot run, dot test, setup.sh, components, re-run the X module, add this to my dotfiles, make that persistent."
---

# Dotfiles (`~/dev/dotfiles`)

Modular cross-platform dotfiles: `bin/dot` → `script/<system>_installation.sh` → each module's
`script/<module>/[<platform>/]setup.sh`, which symlinks `configs/<tool>/` home. The repo's **`AGENTS.md` is the
rulebook** (traps, required checks, security). Read it before a non-trivial change. Details are in
`docs/agent-reference.md`.

## You are the interactive layer

`dot -i` / `dot -m` are TUI menus. **Don't run them.** Ask the user in chat instead, then use the non-interactive
commands:

```bash
cd ~/dev/dotfiles
./bin/dot -c                 # this machine's config: system (mac, linux_omarchy, …) + personal/work
./bin/dot run                # list modules for this system; first line "# system=… environment=…"
./bin/dot run macos rift/mac # run those modules' setup.sh (no prompts; unknown module = exit 1)
./bin/dot --work run         # override personal/work (also --personal, --system <name>)
./bin/dot test [filter]      # run every *_test.sh (or paths containing filter); 77 = skipped
```

The system comes from `.dotconfig`, or is auto-detected when that's empty. Personal vs work decides which modules
are listed (work-only guards in `script/<system>_components.sh`).

## Making a change

1. **Find the owner.** The config is in `configs/<tool>/`; its installer is in `script/<tool>/setup.sh`. macOS
   `defaults write` tweaks all go in `script/macos/setup.sh`.
2. **Edit the repo, not the live copy.** Most configs are symlinked, so an edit is live at once. Exception:
   `~/.claude/settings.json` is a *copy* of `configs/claude/settings.{personal,work}.json`, and rerunning the
   `claude` module overwrites live edits.
3. **New module:** create `script/<name>/setup.sh` (copy a neighbouring one's shape) and add it to
   `script/<system>_components.sh`. For a work-only module use
   `if [[ "${WORK_ENV:-}" == "1" ]]; then component_installation+=(name); fi`. Never use `[[ … ]] && …`, which
   breaks `set -e`.
4. **Apply it:** `./bin/dot run <module>`. To apply a one-off tweak right away, also run the command itself (e.g.
   a `defaults write`), since `run` re-executes the whole module.
5. **Test:** `./bin/dot test`. Changed code with a `*_test.sh` next to it? Add a case. `AGENTS.md` lists the
   required checks.

## Ground rules

- **Public repo: never commit secrets**, tokens, real IPs/hostnames, or `.env` values. Inspect every untracked file
  before staging.
- The tree is often dirty with unrelated work. Stage and commit **only the files you changed**
  (`git commit -- <paths>`).
- Commit/push only when asked. Messages are conventional: `fix(skills): …`, `feat(dot): …`.
- New skills go in `configs/skills/<name>/SKILL.md`. `script/skills/setup.sh` projects them into
  `~/.claude/skills`, `~/.codex/skills`, etc.
