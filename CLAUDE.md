# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

It deliberately documents only what **cannot be recovered by reading the repo** — the traps that fail
silently, the systems this repo doesn't control, and the checks that must be run. Anything derivable
from the source (command flags, directory layout, the logging API, the symlink algorithm, the shape of
a component `setup.sh`) is left to the source, which can't go stale.

> [!IMPORTANT]
> **NEVER commit secrets or sensitive information.** This is a public repository. Do not add private keys, API tokens, passwords, `.env` values, real IP addresses/hostnames, or any machine-specific credentials — not even temporarily. Before staging files, inspect any new/untracked file (especially anything with `600` permissions or in a config dir) for sensitive content. Use the template/`Include`/`source` patterns described in [Security — No Sensitive Data in This Repository](#security--no-sensitive-data-in-this-repository).

## Repository Overview

Opinionated, cross-platform dotfiles supporting macOS, Linux (Fedora, Ubuntu, Arch), and WSL with personal/work environment configurations. Uses a modular, script-based architecture with symlink-based configuration management.

### Target Systems

These dotfiles are actively used across four environments:

| System | Platform | Profile | Use Case |
|--------|----------|---------|----------|
| **Main desktop** | Arch Linux | `linux_arch` / personal | Primary dev machine — full setup with Hyprland, VPN split tunnel, all tools |
| **Work laptop** | macOS | `mac` / work | Work environment — work git email, rift WM + SketchyBar |
| **Personal laptop** | Arch Linux (omarchy) | `linux_omarchy` / personal | Omarchy base + dotfiles CLI/dev layer (omarchy-safe subset — see Omarchy notes) |
| **LXC containers** | Ubuntu/Debian (homelab) | `linux_server` | Lightweight — tmux, neovim, zsh, git only (no desktop/GUI components) |

> [!IMPORTANT]
> `script/` also carries `linux_fedora` and `linux_ubuntu` profiles. **Nothing runs them.** Don't infer
> from their existence that they're supported, and don't spend effort keeping them current.

When adding new features, consider which systems they apply to. Desktop-specific configs (Hyprland, VPN, fonts) only belong in the full Arch/mac profiles. Core CLI tools (tmux, nvim, zsh, git) should work across all profiles including the server/LXC setup.

## Orientation

`boot.sh` (curl-able bootstrap) → `bin/dot` (CLI, system detection, `.dotconfig`) →
`script/<system>_installation.sh` → `run_components` → `script/<component>/[<platform>/]setup.sh`.
Configs live in `configs/<tool>/` and are symlinked home by `script/common/symlink.sh`.
Run `./bin/dot -h` for the full command surface; read any `script/*/setup.sh` for the component pattern.

Two things about that flow that reading one file won't tell you:

- **Every platform's component list lives in its own `script/<system>_components.sh`** — a side-effect-free
  file that *only* defines `component_installation`. It's the single source of truth shared by the matching
  installer and `bin/dot`'s module-selection menu (which `source`s it). Edit the array there, never in an installer.
- **Components run as child processes**, so one script's `set -e`/env changes stay contained — and they
  only see *exported* variables (`DOT_*`, `WORK_ENV`, `DOT_SYMLINK_MODE`). They cannot share shell state
  with each other, which is why `claude`/`codex` load nvm themselves instead of inheriting it from `node`.

### Script Guidelines

Only the two that aren't obvious from reading a neighbouring script:

- **Export for sub-scripts**: configuration vars must be exported — components run as child processes and only see the exported environment
- **Don't clobber `SCRIPT_DIR` in sourced libs**: shared files that get sourced (like `symlink.sh`) must use a private dir var (e.g. `_SYMLINK_LIB_DIR`) so they don't overwrite the caller's `SCRIPT_DIR`

## Checks That Must Be Run

### Claude Code Statusline

The statusline lives at `configs/claude/statusline.sh` and has a regression test + visual demo:

- `configs/claude/statusline_test.sh` — assertion-based tests (`✓/✗` output)
- `configs/claude/statusline_demo.sh` — side-by-side "expect vs actual" renderings for every scenario

**When modifying `configs/claude/statusline.sh`, always run both:**

```bash
bash configs/claude/statusline_test.sh   # must end with "All N tests passed"
bash configs/claude/statusline_demo.sh   # visually confirm each variation still matches the expect line
```

If you add a new field, branch/PR/worktree case, or line-3 indicator, add a corresponding test in `statusline_test.sh` and a scenario in `statusline_demo.sh` before considering the change complete. The demo doubles as living documentation for every supported rendering.

### Tmux Scripts

Statusline/window-name scripts in `configs/tmux/scripts/` follow the same pattern: pure logic exposed via test hooks, with assertion-based tests alongside. **When modifying `smart_window_name.sh` or `claude_status.sh`, run:**

```bash
bash configs/tmux/scripts/smart_window_name_test.sh   # must end with "All N tests passed"
bash configs/tmux/scripts/claude_status_test.sh       # must end with "All N tests passed"
```

`claude_status.sh` renders the Claude state dot in `status-left` (amber ● waiting / green ● churning / dim ○ idle); its `--classify`/`--render` flags test the mapping without a tmux server.

## Traps

### Touch ID Command Gate (macOS)

AI-initiated sensitive Bash commands require biometric approval via a Claude Code `PreToolUse` hook:

- `configs/claude/hooks/touchid-gate.py` — pattern-matches sensitive commands (sudo, force push, prod AWS profiles, 1Password/keychain access, `curl | sh`, secrets-file reads) and pops an approval dialog. Approved → `allow`; denied → `deny`; biometrics unavailable → falls back to the normal permission prompt (`ask`).
- `configs/claude/hooks/bioprompt.swift` — SwiftUI Liquid Glass approval dialog: the command rendered syntax-highlighted (colors parsed live from the Ghostty theme's dark variant) with Touch ID embedded inline via `LAAuthenticationView`. When biometrics are unavailable (clamshell mode) the same glass card shows Approve/Deny, and Approve opens a glass password card verified locally via OpenDirectory — every popup in the flow is glass. Built by `script/claude/setup.sh` into `~/Applications/BioPrompt.app` (`bioprompt-Info.plist`); `~/.local/bin/bioprompt` is an exec shim into the bundle so the hook keeps calling the same path.
- **YubiKey approval**: a FIDO2 user-presence assertion (libfido2, in `Brewfile.base`) races the other auth paths — a key tap approves, fastest in clamshell mode where Touch ID is unavailable. One-time setup per machine: `bioprompt --enroll` (stores credential id + public key only, under `~/.config/bioprompt/`; each approval verifies a signature over a fresh challenge).
- Wired in the dedicated `settings.{work,personal}.json` files under `hooks.PreToolUse`. **Bootstrap order matters**: the `~/.claude/hooks` symlink must exist before the hook entry is live, or every Bash call is blocked (claude/setup.sh links it).
- This is a tripwire, not a sandbox — pattern matching can be evaded; Claude Code's permission system remains the enforcement layer.

### Claude Settings (dedicated work/personal files)

`~/.claude/settings.json` comes from a **dedicated, complete per-environment
file** — no base/overlay merge. `script/claude/setup.sh` **copies** (not
symlinks) `configs/claude/settings.work.json` or `settings.personal.json`
verbatim to `~/.claude/settings.json`. Work-only plugins
(`nest-*@nest-genomics-skills`) and the `nest-genomics-skills` marketplace live
only in `settings.work.json`, so personal machines never see them.

**Environment selection lives in one place: `script/common/dot_env.sh`.** Source
it and call `dot_export_env`; it sets `DOT_ENV` (`work`|`personal`) and aligns
the `WORK_ENV`/`DOT_ENVIRONMENT` exports. Precedence:

1. `WORK_ENV=1` — explicit override.
2. non-empty `DOT_ENVIRONMENT` — how `bin/dot` drives component scripts.
   (`bin/dot` exports `WORK_ENV=""` *empty* for personal, so an empty `WORK_ENV`
   carries no signal — only `DOT_ENVIRONMENT` is authoritative there.)
3. **`.dotconfig`'s `DOT_ENVIRONMENT`** — the standalone path.
4. personal — safe default.

> [!IMPORTANT]
> Rule 3 is load-bearing. Component scripts are a documented **standalone**
> install path (`./script/claude/setup.sh`) where `bin/dot` has exported nothing.
> Without the fallback a work machine silently installs the **personal** config,
> dropping the touchid-gate + prod-AWS tripwires and every `nest-*` plugin/skill
> — a security regression that fails silently. `.dotconfig` is `source`d (in a
> subshell, so it can't clobber caller vars), not grepped: a `grep|cut '"'` parse
> mis-reads an unquoted `DOT_ENVIRONMENT=work` and falls right back into the bug.

All three consumers (`claude/setup.sh`, `claude/sync-settings.sh`,
`skills/setup.sh`) share it, so forward (setup) and reverse (sync) can't disagree
about which machine this is. They previously had **three different** semantics.
**When touching env resolution, run:**

```bash
bash script/common/dot_env_test.sh   # must end with "All N tests passed"
```

Each dedicated file is the **single source of truth** for its environment and
holds the whole settings object (including runtime keys like `effortLevel`).
Because setup.sh copies rather than merges, re-running it **overwrites** the live
file — so capture live edits first:

- **Forward**: `script/claude/setup.sh` → copies active file to `~/.claude/settings.json`.
- **Reverse**: **`claude-settings-sync`** (alias for `script/claude/sync-settings.sh`)
  copies the live file back into this env's dedicated file. 1:1 copy, no routing;
  env resolved from `.dotconfig` (`DOT_ENVIRONMENT`) or `WORK_ENV=1`.

The two files are **independent** — a setting you want on both machines must be
made in both (review `git diff configs/claude/settings.*.json`). `nest-*` skills
in `configs/skills/` are similarly projected by `script/skills/setup.sh` only in
work mode (and pruned elsewhere).

### Claude Instructions (CLAUDE.md work/personal split)

`~/.claude/CLAUDE.md` (Claude's global memory) is **generated, not symlinked**, by
`script/claude/setup.sh` — same base+overlay pattern as `settings.json`:
`configs/claude/CLAUDE.md` (shared base) concatenated with `CLAUDE.work.md` or
`CLAUDE.personal.md` (selected via `WORK_ENV`/`DOT_ENVIRONMENT`). The final file
**must keep the name `CLAUDE.md`** because that's what Claude Code reads; it is a
real file, not a symlink to an overlay. A hidden marker line
(`<!-- @dot-overlay:<env> -->`) is inserted between base and overlay.

**Editing both directions:**
- Edit the repo sources (`configs/claude/CLAUDE.{md,work,personal}.md`) then re-run
  `script/claude/setup.sh` to regenerate — *or* —
- Edit `~/.claude/CLAUDE.md` live, then run **`claude-sync`** (alias for
  `script/claude/sync-claude.sh`) to split your edits back into the base + active
  overlay at the marker. Content above the marker → base (shared); below → the
  active overlay. The round-trip is stable (sync-back then regenerate is a no-op).

`claude.local.md` remains untracked/machine-local for true per-machine notes —
prefer the tracked overlays for anything you want version-controlled and synced.

### Claude Code Themes (custom)

Custom themes live in `configs/claude/themes/`, symlinked whole-dir to
`~/.claude/themes` by `script/claude/setup.sh`. Unlike settings/CLAUDE.md, themes
are **not** work/personal-gated — one dir, shared by both. Ships
`catppuccin-mocha.json` (Mocha to match `bat`, rift borders, and the GTK cursor).

**The slug is the FILENAME, not the `name` field.** `catppuccin-mocha.json`
registers as `custom:catppuccin-mocha`; `name` is only the label shown in
`/theme`. Select via `/theme`, or set `"theme": "custom:<slug>"` in **both**
`settings.work.json` and `settings.personal.json` (they're independent files).

```json
{"name": "Catppuccin Mocha", "base": "dark", "overrides": {"claude": "#fab387"}}
```

- `base` ∈ `dark`, `light`, `dark-ansi`, `light-ansi`, `dark-daltonized`, `light-daltonized`.
- Colors: `#rrggbb`, `#rgb`, `rgb(r,g,b)`, `ansi256(n)`, or `ansi:<name>` where
  `<name>` is one of exactly 16: `black`, `red`, `green`, `yellow`, `blue`,
  `magenta`, `cyan`, `white` and their `…Bright` variants. **`ansi:` is a
  membership test** — `ansi:orange` is silently dropped, not an error.
- `overrides` merges over `base`, so a partial theme is fine — 72 keys available.

> [!IMPORTANT]
> **The loader is silently lossy.** An override with a misspelled key, an invalid
> color, or a bogus `base` is **dropped with no error** — the theme just renders
> wrong. Non-`.json` files in the dir are ignored by Claude Code (which is why the
> preview script can live alongside the themes). Always run `--check`:

```bash
configs/claude/themes/theme_preview.py            # render every theme: swatches + mock UI
configs/claude/themes/theme_preview.py --check    # validate; non-zero exit on problems
```

`theme_preview.py` re-implements an **undocumented** contract reverse-engineered
from the Claude Code binary (`ghg()`/`JOe()`/`Wdi`/`Kpg`/`mhg`), so it **will
drift on upgrades**. `theme_test.sh` pins it — a `--check` that passes a theme the
loader would gut is worse than none, since it certifies the bug. **When modifying
`theme_preview.py`, run:**

```bash
bash configs/claude/themes/theme_test.sh   # must end with "All N tests passed"
```

If it fails after a Claude Code upgrade, re-extract the contract:

```bash
V=~/.local/share/claude/versions/<version>
strings -n 4 "$V" | grep -o 'function JOe(e).\{0,700\}'   # color validator
strings -n 3 "$V" | grep -o 'Kpg=[^;]\{0,300\}'           # the 16 ansi names
strings -n 3 "$V" | grep -o 'Wdi=\[[^]]*\]'               # valid `base` values
```

**Authoring rules** (reverse-engineered from the built-in themes — follow them or
a new theme will look subtly off):

- **Shimmer keys brighten additively** (~`+38`/channel, clamped at 255) — they are
  *not* blended toward white. Built-in dark: `inactive` 153 → `inactiveShimmer` 193.
- **`subtle` is darker than `inactive`** (built-in dark: 80 vs 153 grey), not the
  reverse. `background` is a teal *accent* in both light and dark — not a fill.
- **Diff fills need a monotonic chroma hierarchy**: `Dimmed` < normal < `Word`
  (Mocha uses 0.12 / 0.25 / 0.55 mixed over `base`). Don't luminance-match the
  built-in theme — its diffs are dark *saturated* colors, and mixing scales chroma
  linearly, so a pastel palette like Catppuccin can never reach that saturation.
  Chasing it inverts `Dimmed` and normal, collapsing the two into one shade.

### Agent Skills

Shared agent skills live in `configs/skills/` (one directory per skill, each with a `SKILL.md` plus optional `references/`, `templates/`). `script/skills/setup.sh` projects each skill into every agent CLI (`~/.claude/skills/`, `~/.cursor/skills/`, `~/.codex/skills/`) via per-skill symlinks, so **every skill committed here is version-controlled and syncs to all machines** — including the LXC server, which needs no `npx`/Node to use them. (`configs/claude/skills` is itself a symlink to `../skills` for backward compatibility.)

**Adding a skill from the open ecosystem** (`npx skills`, browse at https://skills.sh):

```bash
# ALWAYS use --copy so real files land in the repo dir, not a symlink
npx skills add <owner/repo@skill> --copy -a claude
git add configs/skills/<skill> && git commit
```

> [!IMPORTANT]
> **Never `npx skills add` without `--copy`.** A bare install symlinks the skill into `~/.claude/skills/<name>` pointing at the machine-local CLI store `~/.agents/skills/` (untracked). That commits a **broken symlink** that dangles on every other machine. `--copy` writes real files instead. (This is exactly how `prd/SKILL.md` ended up a dangling absolute symlink — `find -L configs/skills -type l` lists such breakage on both macOS and Linux.)

Hand-authored skills are just a directory with a `SKILL.md`. Create one with `npx skills init <name>` inside `configs/skills/`, or by hand. Skills are public — never commit secrets, API keys, or real hostnames (see the Security section).

### Tmux Continuum Caveat

**tmux-continuum auto-save relies on a `#(continuum_save.sh)` call embedded in `status-right`.**
Any custom `status-right` set **after** `run '~/.tmux/plugins/tpm/tpm'` will overwrite continuum's hook and silently break auto-save. When customizing the statusline, always include:
```bash
#(~/.tmux/plugins/tmux-continuum/scripts/continuum_save.sh)
```
at the start of your `status-right` value. It produces no visible output — it purely triggers the save-interval check on each status bar refresh.

- Save files live at `~/.local/share/tmux/resurrect/`
- Manual save/restore: `<prefix> + S` (save) / `<prefix> + R` (restore)
- Current auto-save interval: 1 minute (`@continuum-save-interval '1'`)

### Secrets: Lazy 1Password Fetch

`.zshrc.sec` is rendered from an environment-specific template (`.zshrc.sec.work.tpl` / `.zshrc.sec.personal.tpl`, selected by `WORK_ENV` in `script/zsh/setup.sh`). Two patterns:

- **Injected** (`{{ op://... }}`): resolved at setup by `op inject` — plaintext at rest; only for low-sensitivity values.
- **Lazy** (recommended): templates export only `*_REF="op://..."` references; the `opsec` helper (`.zshrc.functions`) runs `op read` at use-time, so 1Password prompts Touch ID when the secret is actually used and nothing sensitive sits on disk:
  ```bash
  ELASTIC_STG_API_KEY=$(opsec "$ELASTIC_STG_API_KEY_REF") some-command
  ```

## Platform-Specific Notes

### macOS
- **Menu Bar**: SketchyBar. Restart if frozen: `brew services restart sketchybar`
- **Work variant**: no separate installer — `./bin/dot --system mac --work` runs `mac_installation.sh` with `WORK_ENV=1`/`DOT_ENVIRONMENT=work` exported, which only changes environment-specific config (work git email, etc.), not which components install

### Arch Linux
- **T2 MacBook Support**: requires manual `apple-bce` driver installation
- **Kernel**: use `linux-t2` for MacBook hardware compatibility

### Omarchy (personal Arch laptop)
- **Detection**: `bin/dot` maps Arch + `~/.local/share/omarchy` → `linux_omarchy` profile
- Omarchy owns `~/.config` app configs as **copies** it maintains via `omarchy refresh`/migrations. Those use `cp -f`/`sed -i`, which **follow symlinks** — after `omarchy update`, run `git status` here: a migration can write through a dotfiles symlink into this repo.
- **Excluded on purpose** (see `script/linux_omarchy_components.sh` for the annotated list): `hypr/linux` + `theming/linux` + `rofi/linux` + `btop/linux` (HyDE-specific; `configs/hypr/hyprland.conf` sources `~/.local/share/hyde/` which doesn't exist on omarchy and would break the desktop), `vpn/linux` + `ufw/linux` (omarchy manages DNS via systemd-resolved and its own ufw rules), `dolphin/linux`/`brave/linux`. Package-level: no `podman-docker` (pacman `conflicts=docker` — installing it removes omarchy's docker stack), no `dnsmasq`/`ufw`.
- **Hyprland**: `hypr/omarchy` links only the override files omarchy's `hyprland.conf` sources last (`bindings/looknfeel/input/autostart.conf` + `gpu-perf-*.conf`) from `configs/hypr-omarchy/`. **Never symlink `hyprland.conf` or `monitors.conf`.** Private webapp URLs go in `~/.config/hypr/bindings.local.conf` (seeded by setup, untracked, sourced by `bindings.conf`).
- **Theme system**: never link over `~/.config/mako/config` or `~/.config/btop/themes/current.theme` — omarchy-owned symlinks into `~/.config/omarchy/current/theme/`. The dotfiles ghostty config deliberately decouples ghostty from `omarchy theme set` (hardcodes Rose Pine instead of sourcing the theme file).

### VPN Split Tunneling (AirVPN + WireGuard)

Split-tunnel VPN that routes all traffic through AirVPN **except** configurable domains (streaming CDNs, etc.) which route directly. Scripts and rules live in `configs/vpn-split/`; `script/vpn/linux/setup.sh` wires them up.

The bypass chain: **dnsmasq** intercepts DNS queries → adds resolved IPs to an **nftables** dynamic set → nftables marks matching packets with `fwmark 0x2` → **ip rule** routes marked packets through the main table (direct) instead of the WireGuard tunnel. Set entries auto-expire after 1 hour.

- **Domain list is local only**: `~/.config/vpn-split/exclude-domains.txt` is never committed. The repo only contains `exclude-domains.example.txt` as a template.
- **WireGuard config is not managed by dotfiles**: `/etc/wireguard/airvpn.conf` contains private keys and must be manually placed. Generate at https://airvpn.org/generator/ (WireGuard protocol).
- **After editing domains**: run `vpn-gen-config` then `sudo systemctl restart dnsmasq` (or just `vpn-down && vpn-up`).

## Security — No Sensitive Data in This Repository

This is a **public dotfiles repository**. Never commit secrets, credentials, or machine-specific data.

**Never commit or create files containing:**
- Private keys (SSH, GPG, TLS) — `id_rsa`, `id_ed25519`, `*.pem`, `*.key`
- API tokens, passwords, or authentication credentials
- `.env` files with real values
- IP addresses, hostnames, or network topology of real machines
- Personal identifiers beyond what's already public (name, public email)

**Safe patterns already in use — follow these:**
- `.dotconfig` — generated at install time, gitignored; stores `DOT_NAME`, `DOT_EMAIL`, etc.
- `configs/ssh/config` — uses `Include ~/.ssh/hosts.local` so real host aliases stay local
- `configs/git/.gitconfig.template` — variable substitution (`DOT_EMAIL`, `DOT_YUBIKEY`) at install time
- `.zshrc.sec` — gitignored file for secret shell exports, rendered from `.zshrc.sec.{personal,work}.tpl`; prefer lazy `op://` references + `opsec` over injected plaintext (see [Secrets: Lazy 1Password Fetch](#secrets-lazy-1password-fetch))

**When adding new configurations:**
- Use templates with `DOT_*` variable substitution for user-specific values
- Use `Include` or `source` directives to load machine-specific files that are gitignored
- Add any new sensitive file patterns to `.gitignore`
- Prefer placeholder/example values over real ones in committed configs
