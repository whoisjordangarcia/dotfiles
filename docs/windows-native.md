# Windows-native profile — design

Date: 2026-11-02 · Status: design approved; rollout step 1 landed (profile slot, installer, LF rules, CI workflow); steps 2–7 are not implemented. This file is canonical.

## Goal

Give the Windows PC a first-class dotfiles profile alongside `mac` and `linux_omarchy`: a curl-able, WinUtil-style
(Chris Titus Tech) checklist that is **lighter** than WinUtil and covers only what the user wants — selected tools,
Windows optimisation tweaks, and the PC's hardware tooling (4090 undervolt, monitoring, fan control).

## Scope

In: Git/CLI (git, ssh, gh, lazygit), Claude/agents (settings, shared memory, skills, codex/opencode config),
glazeWM + Windows Terminal, Windows tweaks (privacy, debloat, Explorer/UX, performance/power), hardware group
(MSI Afterburner + saved undervolt profile, FanControl, HWiNFO, LibreHardwareMonitor).

Out: neovim, starship and a PowerShell profile (explicitly not wanted on Windows); zsh, tmux, ghostty (no native
build); WSL (not chosen); a general-purpose app catalogue (that is WinUtil's job).

## Architecture

Fresh box flow: `bootstrap.ps1` → winget installs Git for Windows (ships bash) → Git Bash runs `bin/dot` →
`script/windows_installation.sh` → `run_components` → each module's `setup.sh`.

| Piece | Role |
|---|---|
| `bootstrap.ps1` (repo root) | Curl-able (`irm <raw-url> \| iex`). Checks Developer Mode, installs Git for Windows, clones the repo, shows the checklist, runs `dot run <modules>` under Git Bash. Elevates only if an admin-tier group is picked. |
| `script/windows_components.sh` | Side-effect-free; defines `component_installation` (same contract as the other `*_components.sh`). |
| `script/windows_installation.sh` | Same shape as `mac_installation.sh`. |
| `bin/dot` `detect_system` | New `msys*\|cygwin*` branch returning `windows`. Git Bash reports `OSTYPE=msys`, which matches nothing today. |

Reused unchanged: `symlink.sh`, `dot_env.sh`, `run_components`, `log.sh`, the test runner.

Symlinks: `script/common/symlink.sh` exports `MSYS`/`CYGWIN=winsymlinks:nativestrict` so `ln -s` makes real NTFS
symlinks and fails loudly rather than silently copying. Requires Developer Mode, which `bootstrap.ps1` will check first. Claude settings stay a *copy*, as on
macOS.

## Checklist groups (bootstrap UX)

Plain numbered `Read-Host` prompt (works in Windows PowerShell 5.1 and PowerShell 7; `Out-GridView` is absent from 7).
Nothing runs until the user confirms the resolved module list.

| # | Group | Tier | Default |
|---|---|---|---|
| 1 | Git / CLI | user | on |
| 2 | Claude / agents | user | on |
| 3 | glazeWM + Windows Terminal | user | on |
| 4 | Privacy / telemetry | user (HKCU) + admin (HKLM policy) | on |
| 5 | Debloat | admin | **off** |
| 6 | Explorer / UX | user | on |
| 7 | Performance / power | admin | on |
| 8 | Hardware (Afterburner, FanControl, HWiNFO) | admin | on |
| 9 | BIOS / RAM audit (read-only) | user | on |

## Modules

- Each tweak module is `script/windows/<name>/setup.sh`, a shim calling
  `powershell.exe -NoProfile -File configs/windows/<name>.ps1` so `dot run` stays uniform.
- **Tweak data is vendored from WinUtil (MIT), not hand-written.** `configs/windows/tweaks.json` and
  `configs/windows/appx.json` hold only the entries the user selected, copied from ChrisTitusTech/winutil
  `config/tweaks.json` / `config/appx.json`, pinned to a recorded commit SHA, with the licence and source commit in
  `configs/windows/THIRD_PARTY.md`. The format is WinUtil's: `registry[]` with `Path/Name/Value/Type/OriginalValue`
  (`<RemoveEntry>` = delete on undo), optional `service[]`, `InvokeScript`/`UndoScript`. Rationale: a wrong registry
  key breaks Windows, and WinUtil's catalogue is vetted by a large user base. Refreshing is a manual, reviewed
  re-copy at a new SHA; nothing downloads WinUtil at install time.
- **Our own runner** (`configs/windows/Invoke-Tweaks.ps1`) applies and undoes those entries. It adds what WinUtil
  lacks: user/admin tiers and a *dynamic* undo log — the value found on this machine at apply time is recorded in
  `~/.local/state/dot/windows-undo.json` and restored on undo (WinUtil's `OriginalValue` is the Windows default, which
  is wrong for a machine the user had already customised). Every step is idempotent.
- **Tweak and debloat groups do not need Git Bash.** They run from `bootstrap.ps1` in PowerShell directly, so they work
  before Git for Windows is installed; only the dotfile groups (Git/CLI, Claude/agents, glazeWM + terminal) go through
  `bin/dot`.
- **Presets:** `bootstrap.ps1` accepts `-Preset Minimal|Standard|Full` and `-Groups <list>` for unattended runs, via
  `& ([ScriptBlock]::Create((irm <pinned-raw-url>))) -Preset Standard` (the form WinUtil uses, because `irm | iex`
  cannot pass parameters). Pester tests validate the JSON (every registry entry has an `OriginalValue`; every preset
  key exists) and run in the Windows CI job.
- **Debloat:** only apps listed in `configs/windows/appx.json` (vendored subset, WinUtil format: `PackageId`,
  `StoreId`) are removed, including their provisioned copies so they do not return for new users. Each run prints the
  list and asks to confirm. The user edits the JSON, not the script.
- **Restore point:** `Checkpoint-Computer` runs before any admin-tier step.
- **Terminal:** Windows Terminal (ships with Windows 11, no install); its `settings.json` is versioned in
  `configs/windows/`.
- **Hardware:** winget installs `Guru3D.Afterburner`, `Rem0o.FanControl`, `REALiX.HWiNFO` and
  `LibreHardwareMonitor.LibreHardwareMonitor` (IDs from memory; the module runs `winget show <id>` first and fails
  clearly on a wrong ID). It restores the Afterburner profile (`Profile1.cfg`, the 4090 voltage/frequency curve) and
  the FanControl config from `configs/windows/hardware/`, and enables "apply at startup". FanControl owns case and CPU
  fans; Afterburner owns only the GPU fan curve, so they never contend for a header.

## BIOS / RAM audit (read-only)

Windows cannot write BIOS settings or DRAM timings on a custom-built PC; those are firmware-only. The module
`script/windows/bios-audit/setup.sh` therefore **reports, never changes**: it prints a pass/fail table and, for each
failure, the exact BIOS setting to change. The user applies fixes by hand in BIOS.

| Check | Source | Pass condition |
|---|---|---|
| RAM running at rated speed (XMP/EXPO on) | `Win32_PhysicalMemory` `ConfiguredClockSpeed` vs `Speed` | configured == rated |
| RAM timings (tCL-tRCD-tRP-tRAS) | HWiNFO sensor CSV export (installed by group 8) | recorded in the report for comparison with the kit's rated timings |
| Resizable BAR on | `nvidia-smi -q` BAR1 total | large BAR1 (not 256 MiB) |
| GPU PCIe gen / width | `nvidia-smi --query-gpu=pcie.link.gen.current,pcie.link.width.current` | gen 4 x16 under load |
| Secure Boot / TPM | `Confirm-SecureBootUEFI`, `Get-Tpm` | on / present |
| Virtualization, XMP profile, Above 4G Decoding | `systeminfo`, `Win32_Processor` | virtualization on; others reported as advisory |

The CPU is a Ryzen 9 5900X (AM4, Zen 3, DDR4, PCIe 4.0), so the audit also checks the AMD-specific items:

| Check | Source | Pass condition |
|---|---|---|
| Memory:Infinity Fabric ratio | HWiNFO sensor export (MCLK, FCLK) | FCLK == MCLK (1:1); on DDR4-3600 that is FCLK 1800 |
| RAM speed class | `Win32_PhysicalMemory` | DDR4-3600 CL16 is the AM4 sweet spot; anything under DDR4-3200 is flagged |
| AMD chipset driver / power plan | `Get-CimInstance Win32_PowerPlan` | an AMD Ryzen power plan is present and active |
| Resizable BAR prerequisite | BIOS AGESA version (`Win32_BIOS`) | AGESA new enough for Resizable BAR on the board (advisory) |

Out of scope: tuning secondary/tertiary timings (done in BIOS with a stability tool such as TestMem5 or y-cruncher;
the audit only records the result). Board, CPU and RAM-kit model are read from the machine at run time, not hard-coded.

## Error handling

Today `dot run`/`run_components` stop at the first failing module. The independent-modules behaviour below is
planned for `bootstrap.ps1`: one failure is reported at the end and does not abort the rest. Hard stops: Developer
Mode off, no network for winget. Admin-tier groups without elevation are skipped with a message, not partially run.

## Security

Public repo: no secrets, tokens, hostnames or serials; Afterburner/FanControl configs are inspected before commit.
`irm | iex` runs whatever the URL serves and the user's command gate flags `curl | sh`, so the README documents a
commit-pinned variant and `bootstrap.ps1` stays small enough to read in one sitting.

## Testing

The author's machine is a Mac, so Windows behaviour cannot be exercised locally.

- **Bash tests (run on Mac/Linux):** `detect_system` with `OSTYPE=msys` returns `windows`; every entry in
  `windows_components.sh` has a `setup.sh`; every checklist group maps only to existing components.
- **CI (added in rollout step 1, never yet executed by a runner):** `.github/workflows/test.yml` has a `suites` job
  that runs `script/test.sh` on `macos-latest`/`ubuntu-latest`, and a `windows` job on `windows-latest` that runs
  `script/windows_test.sh` under Git Bash plus a PowerShell parse check. The full suite does not run under Git Bash yet.
- **Manual:** one real run on the PC for registry, winget and Afterburner behaviour.

Required checks from `AGENTS.md` still apply: `bash script/dot_test.sh` for the `bin/dot` change, `./bin/dot test`
before committing.

## Rollout (each step independently committable)

1. `detect_system` msys branch, `windows_components.sh`, `windows_installation.sh`, tests, CI job.
2. `bootstrap.ps1` + Git/CLI and Claude/agents modules.
3. glazeWM and Windows Terminal.
4. User-tier tweaks (privacy HKCU, Explorer/UX).
5. Admin tier: performance/power, debloat, privacy HKLM, restore point.
6. Hardware group.
7. BIOS / RAM audit (read-only report).

## Related, separate from this spec

Drift fix on the Mac (shipped 2026-11-02): `~/.claude/CLAUDE.md` and OpenCode `AGENTS.md` re-linked via
`memory-sync`; Mac-only instructions moved to `configs/agents/machines/mac.md`, now a committed file.

## Known risks for step 2

- Fixed 2026-11-09: `script/git/setup.sh` now moves a `~/.gitconfig` it did not generate to
  `~/.gitconfig_<timestamp>.bak`, and drops `pager = bat` / falls back from `editor = nvim` to `vim` when the tool is
  not on PATH (`script/git/setup_test.sh`). Still unverified on a real Windows box.
- `configs/git/` CRLF is now covered by `.gitattributes` (`configs/git/** text eol=lf`); keep new template dirs covered.
- CI: `timeout-minutes` is set on both jobs. Still to do: use `git ls-files '*.ps1'` instead of a recursive `Get-ChildItem` for the
  PowerShell parse step once `bootstrap.ps1` exists.
- Pin `actions/checkout` to a commit SHA rather than a mutable tag.
