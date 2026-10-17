---
name: win11-vm
description: "Drive the local Windows 11 VM (dockurr container on this laptop) over ssh and `win11ctl` for GUI. Triggers: win11, the vm, win11ctl, omarchywin11, copy to the vm, screenshot/click/type in the VM, run a Windows command. Not the 4090 desktop (ssh superheavy)."
---

# Driving the local Omarchy Windows 11 VM

The local Windows 11 VM is a dockurr/windows container on this laptop, reached over ssh and driven with `win11ctl`
for GUI automation. Use this skill when the user asks to run a Windows command, reach the VM, move files to or from
it, screenshot the desktop, click/type in it, install something, or debug host↔VM connectivity. Triggers: `win11`,
"the vm", `win11ctl`, `omarchywin11`, `172.18.0.2`, `WIN-37LQ4CJQ6J5`, "copy to the vm".
Container lifecycle, readiness checks, RAM/disk config and footguns are all in this file — it is the only VM
reference here.
>
> **This is NOT the 4090 Windows desktop.** That box is a separate host (`ssh superheavy` / `win11`).

## The two-mechanism split

| Need | Mechanism |
|---|---|
| Shell / files / processes | **SSH** — lands in Session 0, **no GUI** |
| Anything visual | **`win11ctl`** — scheduled task in the logged-in desktop session |

**SSH cannot see the desktop.** It runs in Session 0 with no interactive session attached;
launching a GUI app over SSH gives a process that never paints. `win11ctl` exists to work
around exactly that.

## SSH

```bash
ssh -q -i ~/.config/windows/vm_ed25519 -o IdentitiesOnly=yes -o BatchMode=yes \
    -o WarnWeakCrypto=no omarchywin11@172.18.0.2 "powershell command"

win11ctl ssh [cmd]        # wrapper with key + options baked in
```

| | |
|---|---|
| Host | `omarchywin11@172.18.0.2` — container IP on the docker bridge |
| Hostname | `WIN-37LQ4CJQ6J5` |
| OS | Windows 11 Pro, build `10.0.26200` (verified 2026-10-10) |
| Key | `~/.config/windows/vm_ed25519` (comment `claude-win11-vm`) |
| Shell | PowerShell (set as `DefaultShell` in HKLM at bootstrap) |

- **No `&&` or `&`.** Use `;`.
- No TTY for password prompts — never trigger interactive elevation.
- The IP is **hard-coded** in `~/.local/bin/win11ctl` (`HOST=`). If Docker reassigns it, every
  call fails with a generic timeout — check, then edit `HOST=`.

The key is authorised in `C:\ProgramData\ssh\administrators_authorized_keys`. Admin accounts
ignore `~\.ssh\authorized_keys`, and sshd silently ignores that file unless only
`Administrators` + `SYSTEM` can access it (`icacls ... /inheritance:r`).

## win11ctl (GUI only)

```bash
win11ctl shot [file.png]          # screenshot; prints WxH and path
win11ctl click X Y [right|double]
win11ctl move X Y
win11ctl scroll N                  # N>0 up, N<0 down
win11ctl type "text"               # literal text
win11ctl key "^c"                  # SendKeys: ^ctrl %alt +shift {ENTER} {TAB}
win11ctl ssh [cmd]                 # PowerShell over SSH
win11ctl install                   # re-copy agent + recreate task (once)
```

`run.ps1` base64-encodes the command, writes it to a file, and starts the `w11` scheduled task
— created with **`/IT` (interactive only)** so Windows runs it *inside* the logged-in desktop
session. `agent.ps1` acts (`CopyFromScreen`, `SetCursorPos` + `mouse_event`, `SendKeys`), then
writes a `done` file. `SetProcessDPIAware()` runs first, so **screenshot pixels equal click
coordinates** even under RDP `/scale:180`.

Files: `~/.local/bin/win11ctl`, `~/.local/share/win11ctl/{agent,run}.ps1`; in Windows,
`%USERPROFILE%\w11\` plus scheduled task `w11`.

## File transfer

**`~/Windows/` is a plain directory on this Linux host — it is NOT mounted in the guest.**
Verified: the VM reports only `C:\`. Treat it as a staging folder for manual copy, not a
share. (Its `enable-ssh.ps1` is a leftover from an older topology and has already been
applied; do not re-run it.)

Real transfer is `scp` with the VM key:

```bash
scp -q -i ~/.config/windows/vm_ed25519 -o IdentitiesOnly=yes ./file.zip \
    omarchywin11@172.18.0.2:w11/
```

## Gotchas specific to this path

- **GUI work needs a logged-in desktop session.** Otherwise `win11ctl` hangs to timeout. If
  readiness checks first.
- **`docker ps` returning `permission denied` is correct**, not broken. You are deliberately
- **Ports `:8006` and `:3389` bind to `127.0.0.1` only.** Nothing on the LAN can reach this VM.
- **`pkexec` fails over SSH** (polkit "No session for cookie"). Start the VM from the desktop
  instead — `win11-web`, or the `Windows` desktop entry (Super+Space).
- **`sudo` from a non-interactive agent shell hangs** on the password prompt.
- **No Win key** via SendKeys — use `^{ESC}` for Start.
- **~1 s per `win11ctl` command.** Fine for screenshot-and-click loops, wasteful for scripting.
- **Remote scripts need `-ExecutionPolicy Bypass`** per process; system policy left at default.

## Not this box: the 4090 desktop

The `win11-4090` model provider in `~/.config/opencode/opencode.json`
(`http://127.0.0.1:8081/v1`) belongs to the **separate 4090 Windows desktop**, not this VM —
it is a model endpoint, not a machine-control channel.

That box is **not reachable from here right now** (no route to `.95` or `.25` as of
2026-10-10, and no local listener on 8081). Its address is genuinely ambiguous — `.95` vs
`.25`, plus a `jordan` vs `jordangarcia` user mismatch — and that is documented as an open
item in the VM's own config. Do not guess; read the file.

## Teardown

```powershell
schtasks /delete /tn w11 /f
```

Then delete `%USERPROFILE%\w11` and remove the `claude-win11-vm` line from
`C:\ProgramData\ssh\administrators_authorized_keys`.

## Related

vault note `~/dev/notes/02 - Code/2026-10-10 win11ctl claude drives the omarchy win11 vm.md`
