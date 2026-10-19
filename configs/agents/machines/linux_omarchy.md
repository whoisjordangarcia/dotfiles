# linux_omarchy — personal MacBook Pro 15 laptop

## Machine

MacBook Pro 15,1 (2018, T2) laptop running Omarchy Arch; dual GPU (Intel drives the panel, AMD 560X drives external
output), Hyprland/Wayland, dotfiles in `~/dev/dotfiles` symlinked into `~/.config`.

- **Details live in notes, not here.** Hardware tables, the T2 USB-C Alt Mode dead end, the macOS+Linux CDP/browser
  recipe, remote Things 3 on the macmini and the other machines:
  `~/dev/notes/02 - Code/MacBook Pro 15 (omarchy) machine reference.md`. Memory pipeline, skill farms and harness
  quirks: `~/dev/notes/10 - Meta/Agent memory and skills setup.md`. Read a note when the task touches it, not before.
- `sudo` or anything this shell can't run: put it on the clipboard with `wl-copy` rather than only printing it.
- `opencode` on `PATH` is OpenCode **V1**; the V2 config (`~/.config/opencode/opencode.json`) needs **`opencode2`**.

## MCP tools in Code Mode (`execute`)

- `ida_*` is called directly; `rea` and other big servers live inside `execute`
  (`const r = await tools.rea.open_binary({ path: "/abs/path" }); return r;`).
- A `tools.*` call returns the payload itself: `return r`, never `r.result` (undefined → null).
- Unsure of a tool's params: `return await search({ query: "binary_overview", namespace: "rea" })` — don't guess and
  don't grep node_modules or websearch for docs. `rea` needs `open_binary` first; `ida` needs `idb_open`
  (Windows path inside the VM), see the `ida-vm` skill.
