# Server / Proxmox Bash Config

Lightweight Bash environment for headless Linux servers, Proxmox hosts, and LXC
containers — no desktop, no zsh, just `bash`, `tmux`, `neovim`, and **Claude Code**.
This is intentionally separate from the main `bin/dot` installer (which targets
full workstation profiles); a server only needs these few files symlinked plus a
couple of tools.

## What gets installed

| Layer | Installs | Where |
|-------|----------|-------|
| **System packages** (apt) | `git curl vim neovim tmux htop` | `server-init.sh` — the one-liner bootstrap |
| **Claude Code** | native installer → `~/.local/bin/claude` | `server/setup.sh` (no node/npm/pnpm needed) |

`bashrc` already puts `~/.local/bin` first on `PATH`, so `claude` works in any new
shell right after install. Skip the Claude install with `SKIP_CLAUDE=1`.

## What gets linked

`setup.sh` symlinks these into your home directory (backing up any existing
files to `~/.dotfiles_backup_<timestamp>/` first):

| Source (in repo)        | Symlinked to                          |
|-------------------------|---------------------------------------|
| `server/bashrc`         | `~/.bashrc`                           |
| `server/bash_profile`   | `~/.bash_profile`                     |
| `server/aliases`        | `~/.bash_aliases`                     |
| `server/tmux.conf`      | `~/.tmux.conf`                        |
| `functions/*.sh`        | `~/.config/bash/functions/` (repo root, shared) |
| `gitconfig`             | `~/.gitconfig` (repo root, shared)    |

> `functions/` and `gitconfig` live at the **repo root** because they're shared
> with the rest of the dotfiles. Everything server-specific lives in `server/`.

## Install

### One-liner (fresh server)

Installs `git curl vim tmux htop` (via apt), clones the repo to `~/dotfiles`,
and runs the setup:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/whoisjordangarcia/dotfiles/main/server-init.sh)
```

### Manual

```bash
git clone https://github.com/whoisjordangarcia/dotfiles.git ~/dotfiles
bash ~/dotfiles/server/setup.sh        # symlinks + installs Claude Code
source ~/.bashrc
```

> The manual path does **not** apt-install system packages (that's the bootstrap's
> job) — make sure `neovim`/`tmux` are present, or just use the one-liner.

`setup.sh` is idempotent — re-run it any time to refresh the symlinks. It skips
the Claude Code install if `claude` is already on `PATH`, or set `SKIP_CLAUDE=1`
to skip it entirely.

## Adding to the config

All four config files are plain symlinks, so edits in the repo take effect
immediately (open a new shell or run `rb` to reload `~/.bashrc`).

### Add an alias

Edit `server/aliases` (linked to `~/.bash_aliases`, sourced by `bashrc`):

```bash
alias myalias='some command'
```

### Add a function

Drop a `*.sh` file in the **repo-root** `functions/` directory — `bashrc` sources
every `~/.config/bash/functions/*.sh` on startup:

```bash
# functions/mytool.sh
mytool() {
  echo "does a thing"
}
```

Then re-run `bash server/setup.sh` so the new file gets symlinked into
`~/.config/bash/functions/` (existing files are already linked).

### Add an environment variable / PATH entry

Login-shell setup (PATH, SSH agent, locale, Proxmox bits) lives in
`server/bash_profile`. Interactive-shell tweaks go in `server/bashrc`.

### After any change

```bash
rb            # reload ~/.bashrc (helper defined in bashrc)
# or, if you added a new functions/ file:
bash server/setup.sh
```
