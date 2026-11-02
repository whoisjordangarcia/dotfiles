# mac — personal macOS machine

## Machine

macOS, dotfiles in `~/dev/dotfiles` symlinked home. Read a section when the task touches it, not before.

## Notes vault (`~/dev/notes`)

Plain markdown in a git repo; the vault's own `AGENTS.md` is the rulebook. Rule of thumb: **text matching → native
file tools (`rg`/`Glob`); questions about Obsidian's metadata (tasks, tags, backlinks, frontmatter, orphans) →
`notes-cli` skill** (the official `obsidian` CLI, needs the Obsidian app running). Daily notes → `daily-note` skill;
find/create/organize/commit → `obsidian-vault` skill. Why: `~/dev/notes/10 - Meta/Vault Tooling Decision.md`.

## Browsing

- **Public pages, no login** → `agent-browser-lp <cmd>`: same commands as agent-browser on the Lightpanda engine
  (`~/.local/bin/lightpanda`), headless, ~0.4s opens. It is a wrapper in `~/dev/dotfiles/bin` because the default
  agent-browser config is headed + profile, which Lightpanda rejects. No profiles or logins.
- **Logged-in sessions** (Marketplace, shopping) → drive the real **Brave** over CDP, non-headless. The "Agent
  Browser" Chrome profile does not exist on this Mac. Brave has no CDP port by default: quit it with
  `osascript -e 'quit app "Brave Browser"'`, relaunch with `--remote-debugging-port=9222 --restore-last-session`,
  confirm with `curl -s http://127.0.0.1:9222/json/version`, then `agent-browser --cdp 9222 ...`. Open work in a **new
  tab** (`tab new <url>`) so existing tabs survive; read pages with `snapshot -i` or `eval`, skip screenshots.
- "Chrome profile 'Agent Browser' not found" even with `--cdp` is a stale daemon: `agent-browser close --all`, kill the
  pid in `~/.agent-browser/default.pid`, remove `~/.agent-browser/default.{sock,pid}`, retry.
- A normal Brave quit + reopen closes the debug port again.

## Tasks (Things 3)

Use the `things3` skill (`~/dev/things3-cli`); it has the schema, the Groceries project and the add/trash commands.
Never write the Things SQLite DB directly, and don't `add`/`trash`/`push` without an explicit request.
