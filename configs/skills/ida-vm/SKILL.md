---
name: ida-vm
description: "Reverse engineer a binary with IDA Pro / Hex-Rays through the `ida` MCP (mcp__ida__* tools), running headless idalib inside the local Win11 VM. Triggers: ida, ida mcp, idalib, hex-rays, decompile this dll/exe, open in ida, .i64, idb_open."
---

# IDA Pro MCP (headless, in the local Win11 VM)

## How it's wired

The `ida` MCP server is `ssh omarchywin11@172.18.0.2 '& "$env:USERPROFILE\.local\bin\idalib-mcp.exe" --stdio'`
— IDA Professional 9.1 (`C:\Program Files\IDA Professional 9.1`) runs **inside the VM**.
Configured in `~/.claude.json` (`mcpServers.ida`) and `~/.config/opencode/opencode.json` (`mcp.ida`).

Consequences:
- **`input_path` is a Windows path in the VM.** Host paths (`/home/jordan/...`) don't exist there.
- The `.i64` is written next to the input → never open files in `C:\Windows\System32` (not writable); copy them first.
- Sessions live in a supervisor inside the VM and are **shared across clients** (Claude Code, opencode2): always `idb_list` first and reuse an open session instead of re-opening; don't `idb_close` a session you didn't open.

## SSH into the VM

```bash
win11ctl ssh 'Get-ChildItem $env:USERPROFILE\ida'      # one-off PowerShell command
ssh -i ~/.config/windows/vm_ed25519 -o IdentitiesOnly=yes -o WarnWeakCrypto=no omarchywin11@172.18.0.2   # interactive shell
```

Shell is **PowerShell**: chain with `;`, not `&&`. SSH runs in Session 0 (no GUI) — a GUI app
started over SSH (or via a scheduled task) runs but never shows a window.

## Interacting with the VM desktop (win11ctl)

```bash
win11ctl shot /tmp/opencode/w.png    # screenshot → Read the png; pixels == click coords
win11ctl click X Y [left|right|double]
win11ctl type "text"; win11ctl key "{ENTER}"   # SendKeys: ^ctrl %alt +shift {TAB} {ESC}
win11ctl scroll -3
```

Screen size changes (1024x768 headless vs ~2832x1682 when RDP is attached) — always take a fresh
`shot` before clicking. If you view the image scaled down, multiply coords back up.

**Opening the IDA GUI** (to show the user something, or work manually): screenshot, then
`win11ctl click <x> <y> double` on the desktop **"IDA Professional 9.1"** shortcut (left column),
wait ~15s, screenshot again → "IDA: Quick start" dialog with recent files. To open an analysed
database, `idb_close(save=true)` the MCP session first (the worker locks the `.i64`), then pick it
from the recent list or File → Open. The GUI has **no MCP plugin** — MCP and GUI don't share a
session; `mode="prefer_gui"` won't find it. Kill a stuck GUI with `win11ctl ssh 'Stop-Process -Name ida -Force'`.

## Workflow

1. **Get the binary into the VM** (work dir `C:\Users\omarchywin11\ida\`):
   ```bash
   win11ctl ssh 'New-Item -ItemType Directory -Force $env:USERPROFILE\ida | Out-Null'
   scp -q -i ~/.config/windows/vm_ed25519 -o IdentitiesOnly=yes -o BatchMode=yes -o WarnWeakCrypto=no \
       ./target.dll 'omarchywin11@172.18.0.2:C:/Users/omarchywin11/ida/target.dll'
   ```
   Files already in the VM (e.g. `C:\Users\omarchywin11\eft\*.dll`) can be opened in place.
2. `idb_open(input_path="C:\Users\omarchywin11\ida\target.dll")` → note `session_id`. Big binaries take a while (auto-analysis).
3. `survey_binary(database=<id>)` FIRST (`detail_level="minimal"` if >10k funcs). Don't triage with `list_funcs`/`imports` separately.
4. Dig in: `decompile` (pass `include_addresses=false` to save tokens; follow `cursor.next`), `xrefs_to`, `callees`/`callgraph`, `find_regex`/`search_text`, `lookup_funcs`.
5. Annotate as you learn: `rename`, `set_comments`, `set_type`, `declare_type`.
6. `idb_close(database=<id>, save=true)` to keep the `.i64`; `save=false` for throwaway. Closing frees a worker slot.

Every analysis tool takes `database=<session_id>`. Schemas for the `mcp__ida__*` tools are deferred in Claude Code — load them with ToolSearch (`select:mcp__ida__idb_open,...`).

## Troubleshooting

| Symptom | Fix |
|---|---|
| MCP fails to connect / timeout | VM down or IP moved. Check with the `win11-vm` skill (`win11ctl ssh hostname`). |
| `idb_open` file not found | You passed a host path, or skipped the scp step. |
| Fetching the `.i64` back | `scp ...:C:/Users/omarchywin11/ida/target.dll.i64 .` |
| Copy files back to host | `scp -i ~/.config/windows/vm_ed25519 -o IdentitiesOnly=yes 'omarchywin11@172.18.0.2:C:/Users/omarchywin11/ida/x' .` |
| GUI click does nothing | Stale coords — re-`shot`; a window may have moved or the RDP resolution changed. |

Never run destructive `patch`/`patch_asm` on a binary without the user asking; work on a copy.
