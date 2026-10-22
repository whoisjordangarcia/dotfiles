# AGENTS.md

Rules for any coding agent in this repo (`CLAUDE.md` symlinks here; every harness reads `AGENTS.md`). Anything
derivable from the source — flags, directory layout, the logging API, the symlink algorithm, a component's
`setup.sh` shape — is left to the source. **This file is rules and traps in one line each**; the full rationale,
per-component checks and platform notes are in **`docs/agent-reference.md`** (anchors below).

# dotfiles

Cross-platform dotfiles (macOS, Linux/Omarchy, WSL, LXC) built as modular scripts that symlink configs home.

> [!IMPORTANT]
> **NEVER commit secrets or sensitive information.** Public repo: no private keys, API tokens, passwords, `.env`
> values, real IP addresses/hostnames or machine credentials — not even temporarily. Before staging, inspect any
> new/untracked file (especially `600` perms or anything in a config dir). Use the template/`Include`/`source`
> patterns in `docs/agent-reference.md#security--no-sensitive-data-in-this-repository`.

## Orientation

`boot.sh` (curl-able bootstrap) → `bin/dot` (CLI, system detection, `.dotconfig`) → `script/<system>_installation.sh`
→ `run_components` → `script/<component>/[<platform>/]setup.sh`. Configs live in `configs/<tool>/` and are symlinked
home by `script/common/symlink.sh`. `./bin/dot -h` is the full command surface.

Two things reading one file won't tell you:

- Each platform's component list lives in its own `script/<system>_components.sh` — a side-effect-free file that only
  defines `component_installation`, shared by the matching installer and `bin/dot`'s menu. Edit the array there, never
  in an installer.
- Components run as **child processes**: one script's `set -e`/env changes stay contained and they only see *exported*
  vars (`DOT_*`, `WORK_ENV`, `DOT_SYMLINK_MODE`). Export config vars for sub-scripts; never clobber `SCRIPT_DIR` in a
  sourced lib (use a private `_…_DIR`).

`script/` also carries `linux_fedora` and `linux_ubuntu` profiles: **nothing runs them** — don't infer support from
their existence. Full target-system matrix: `docs/agent-reference.md#repository-overview`.

## Checks that must be run

Each of these pins behaviour you cannot see by reading the code; the rationale and the extra traps are in the
reference doc.

| Change | Run |
|---|---|
| `configs/claude/statusline.sh` | `bash configs/claude/statusline_test.sh` then `statusline_demo.sh` (add a test + scenario per new field/case) |
| `configs/starship/prompt_info.sh` | `bash configs/starship/prompt_info_test.sh` |
| `configs/tmux/scripts/smart_window_name.sh`, `claude_status.sh` | their `*_test.sh` |
| anything under `script/brave/` | `for t in script/brave/*_test.sh; do bash "$t"; done` |
| `configs/claude/hooks/gate_patterns.py`, `touchid-gate.py` | `bash configs/claude/hooks/gate_test.sh` (the codex hook imports the same list — update both) |
| env resolution (`script/common/dot_env.sh`) | `bash script/common/dot_env_test.sh` |
| a component's `setup.sh` | read the neighbouring one; components follow one pattern |
| `bin/dot` | `bash script/dot_test.sh` |
| anything, before committing | `./bin/dot test` — every suite; exit 77 = skipped on this OS/hardware |

Re-run a module without the TUI: `./bin/dot run <module>` (`./bin/dot run` lists them). Each test must end with
"All N tests passed". `docs/agent-reference.md#checks-that-must-be-run` has what each test pins.

## Traps (one line each — full text in the reference doc)

- **Touch ID command gate** (macOS): a `PreToolUse` tripwire on sensitive Bash (sudo, force push, prod AWS,
  1Password/keychain, `curl | sh`, secrets reads) with two modes, `bio` vs `confirm`; scoping only ever *adds*, so a
  broken config means prompt fatigue, never a lost guard. → `#touch-id-command-gate-macos`
- **Claude settings**: `~/.claude/settings.json` is a verbatim **copy** of `configs/claude/settings.{work,personal}.json`
  — no merge, and re-running setup overwrites live edits (capture them first: `claude-settings-sync` copies back).
  Env resolution lives only in `script/common/dot_env.sh`; its `.dotconfig` fallback is load-bearing for the standalone
  install path. → `#claude-settings-dedicated-workpersonal-files`
- **Global agent memory is one file per machine**: `configs/agents/AGENTS.md` (personal) or `AGENTS.work.md`
  (work, picked by `dot_env.sh`) is canonical; per-machine facts go in `configs/agents/machines/<DOT_SYSTEM>.md`,
  never the memory itself. `script/memory-sync.sh` symlinks `~/.claude/CLAUDE.md` and `~/.config/opencode/AGENTS.md`
  to it (`--check` reports broken links;
  `script/claude/setup.sh` calls it). No copies, no base/overlay split, no dot-overlay marker. OpenCode's
  `instructions` config key looks like the tidier answer but is ignored by this build — don't switch to it.
  Projects are `AGENTS.md` only. **Tested on 2.1.287:** a project `CLAUDE.md`/`CLAUDE.local.md` suppresses the
  project's `AGENTS.md`, and the documented `instructionFiles` override is ignored under both plugin IDs — so the
  `pluginConfigs` entry in `settings.{work,personal}.json` is aspirational, not load-bearing. Use `.claude/rules/`
  for extra per-project rules. → `#claude-instructions-claudemd-workpersonal-split`
- **Themes**: the slug is the *filename* (`custom:catppuccin-mocha`); picking one silently disables `"theme": "auto"`,
  so both settings files ship `auto`. Don't "fix" auto by exporting `COLORFGBG`. → `#claude-code-themes-custom`
- **Agent skills**: `configs/skills/` is the canonical set, symlinked into each harness; work-only (`nest-*`) and personal-only
  skills are projected and pruned per env by `script/skills/setup.sh`. **Install with `--copy`** so real files land in the repo, not a symlink.
  → `#agent-skills`
- **SD-card backup** (macOS `StartOnMount`) → `#sd-card-backup-macos-startonmount`
- **T2 dGPU power-off is deliberately disabled — do not re-enable** → `#t2-dgpu-power-off--deliberately-disabled-do-not-re-enable`
- **tmux continuum**: tmux server version skew breaks the plugin; pin per platform → `#tmux-continuum-caveat`
- **Secrets**: 1Password items are fetched lazily, never written into the repo → `#secrets-lazy-1password-fetch`
- **Platform notes** (macOS / Arch / Omarchy / AirVPN split tunneling) → `#platform-specific-notes`

## Platform notes

Four environments: main Arch desktop (full), work macOS laptop, personal Arch/Omarchy laptop (omarchy-safe subset),
server LXC (tmux/nvim/zsh/git only). Desktop-only config (Hyprland, VPN, fonts) belongs to the desktop profiles;
core CLI tools must work everywhere. Per-platform details: `docs/agent-reference.md#platform-specific-notes`.

## Docs

`docs/agent-reference.md` (this repo's agent reference) · `docs/modular-zsh-integration.md`,
`docs/zsh-configuration-systems.md`, `docs/zoxide-zsh-troubleshooting.md` · `docs/ai-tools/`, `docs/ai-benchmark/` ·
`README.md` for the human tour.