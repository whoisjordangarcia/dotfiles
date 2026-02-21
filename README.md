# dotfiles - Otobun

**Opinionated, curated dotfiles for the discerning developer**

Otobun is a comprehensive cross-platform dotfiles repository that makes strong choices about your development environment. Supporting macOS, Linux (Ubuntu, Fedora, Arch), and WSL with both personal and work configurations, it's designed for developers who want a thoughtfully curated setup without the decision fatigue.

> **Why "otobun"?** These dotfiles are opinionated ("oto" from opinionated) and bundled ("bun") together as a cohesive package. No endless options—just curated choices that work across multiple platforms.

## Features

- **Go TUI installer** - Beautiful terminal UI built with Bubble Tea for setup wizard, module selection, and installation progress
- **Opinionated tool selection** - Carefully curated applications and configurations that work well together
- **Cross-platform compatibility** - Consistent experience across macOS, Ubuntu, Fedora, Arch Linux, and WSL
- **Environment-aware setup** - Thoughtfully separated configurations for personal and work environments
- **Zero-decision installation** - Smart system detection with guided setup—no overwhelming choices
- **Modular architecture** - Component-based system with sensible defaults
- **Symlink-based configs** - Centralized configuration management for easy updates
- **AI development tools** - Curated AI assistant rules for Cursor, Aider, and Avante

> [!TIP]
> The system automatically detects your platform and environment, making installation straightforward across different setups.

## Quick Start

### YOLO It

```bash
curl -fsSL https://raw.githubusercontent.com/whoisjordangarcia/dotfiles/main/boot.sh | bash
```

This will automatically clone/update the repo, fetch latest changes, and run interactive setup.

### Interactive Installation (Recommended)

```bash
git clone https://github.com/whoisjordangarcia/dotfiles.git
cd dotfiles
./bin/otobun              # Go TUI experience
```

The `otobun` TUI walks you through setup with a wizard, lets you pick modules with a checkbox selector, and shows real-time installation progress with spinners.

### Alternative Methods

```bash
./bin/dot -i                          # Legacy interactive setup (shell-based)
./bin/dot --system mac --work         # Direct installation
./bin/dot --system linux_ubuntu --personal
./bootstrap.sh                        # Legacy method
```

---

## Configuration Components

### Shell & Terminal

#### Zsh (`configs/zshrc/`)
Modular Z shell configuration with organized `.zshrc-modules/`:

| Module | Purpose |
|--------|---------|
| `.zshrc.history` | 50k command history with smart duplicate filtering, ignores mundane commands |
| `.zshrc.aliases` | `reload`, `vim→nvim`, `ls→eza`, `cat→bat`, `top→btop`, git shortcuts |
| `.zshrc.functions` | `encode64/decode64`, `compress/decompress`, `web2app` launcher creator |
| `.zshrc.plugins` | Completions + plugins: zsh-syntax-highlighting, zsh-autosuggestions, nx-completion |
| `.zshrc.envvars` | EDITOR, pyenv, colored man pages via bat |
| `.zshrc.vim-mode` | Vi keybindings in shell |
| `.zshrc.work` | Work-specific environment config |

**Key Aliases:**
- `gcm` - checkout main, `gpo` - pull origin, `gpf` - push --force-with-lease
- `wt-auto`, `wt-list`, `wt-remove` - git worktree management
- `dotfiles` - quick access to this repo

#### Tmux (`configs/tmux/`)
Terminal multiplexer with extensive customization:

- **Prefix**: `Ctrl+a` (changed from default Ctrl+b)
- **Navigation**: Vim-style with `vim-tmux-navigator` (Ctrl+h/j/k/l seamless pane switching)
- **Session Management**: `tmux-resurrect` + `tmux-continuum` for persistence
- **UI**: Elegant minimal statusline with git status, CPU, memory, battery

**Custom Scripts** (`~/.tmux/scripts/`):
| Script | Function |
|--------|----------|
| `pane_title.sh` | Gradient-colored pane borders by command (Claude=purple, nvim=green, nx=orange) |
| `session_picker.sh` | Process-aware session selection with zoxide integration |
| `cpu_usage.sh` | CPU monitoring for statusline |
| `memory_usage.sh` | RAM usage display |

**Plugins via TPM:**
- `vim-tmux-navigator`, `tmux-yank`, `tmux-resurrect`, `tmux-continuum`
- `tmux-sessionx`, `tmux-floax`, `tmux-prefix-highlight`, `tmux-cpu`, `tmux-battery`

#### Ghostty (`configs/ghostty/`)
Fast, GPU-accelerated terminal emulator:

- **Font**: GohuFont 14 Nerd Font, 16px
- **Window**: No decoration, blur radius 20px, transparent
- **Behavior**: Mouse hide while typing, block cursor, clipboard access enabled
- **Integration**: Shell integration for Zsh, xterm-256color with RGB

#### Starship (`configs/starship/`)
Minimal, fast shell prompt:

- **Format**: Directory → git worktree indicator (🎯) → git branch/status → character
- **Git Status**: Custom symbols for ahead (⇡), diverged (⇕), behind (⇣), conflicts, modifications
- **Character**: Success (❯ cyan), Error (✗ bold cyan)
- **Performance**: 200ms command timeout

---

### Code Editors

#### Neovim (`configs/nvim/`)
LazyVim distribution with 27+ extras enabled:

**AI & Coding:**
- `claudecode` - Claude Code integration
- `yanky` - Enhanced clipboard manager

**Languages:**
- Docker, Git, JSON, Markdown, Prisma, Python, Tailwind CSS, TypeScript, YAML

**Editor Enhancements:**
- `aerial` - Code outline/symbols
- `harpoon2` - Quick file navigation
- `illuminate` - Highlight word references
- `mini-diff` - Inline git diffs
- `outline` - Symbol explorer
- `treesitter-context` - Shows code context at top

**Additional:**
- DAP debugging with Neovim Lua support
- ESLint + Prettier formatting
- Integrated test runner
- Lazy loading for fast startup

#### LazyGit (`configs/lazygit/`)
Terminal Git UI with custom commands:

- **`c` key**: Create draft PR via `gh pr create --web --draft`
- **`n` key**: New branch with type menu (feature/fix/hotfix/chore/docs/refactor)
  - Naming: `jordan/{type}-{name}`
- **Theme**: Catppuccin Mocha (coral borders, blue text, dark background)
- **Features**: Nerd Font icons, fuzzy filter, numstat display, commit signing

---

### Window Managers

#### Aerospace (`configs/aerospace/`) - macOS
i3-inspired tiling window manager:

- **Navigation**: Alt+j/k/l/; for focus, Alt+Shift to move windows
- **Workspaces**: Alt+1-0 for 10 workspaces
- **Modes**: Visual resize mode, accordion layouts (vertical/horizontal)
- **Integration**: Auto-hides dock and menu bar

**Sketchybar Integration:**
- Dynamic status bar with workspace info
- SbarLua for Lua scripting
- Theme switching capability
- Custom app font for icons

#### Hyprland (`configs/hypr/`) - Arch Linux
Modern Wayland compositor:

| Config | Purpose |
|--------|---------|
| `hyprland.conf` | Main entry, sources modular configs |
| `monitors.conf` | Display setup for retina 2x (5K/6K) |
| `input.conf` | Keyboard (US), touchpad settings |
| `looknfeel.conf` | Window rounding (12px), gaps, dwindle layout |

**HyDE Integration**: Uses HyDE distribution for theming and extended configs.

#### Waybar (`configs/waybar/`) - Wayland Status Bar
Customizable panel for Hyprland:

**Modules:**
- **Left**: Power menu, HyDE menu, clipboard, wallpaper switcher, theme selector, Spotify
- **Center**: Clock, idle inhibitor
- **Right**: Privacy, system tray, battery, backlight, network, audio, keybind hints

**Styling:**
- Dark bar with pill-shaped module groupings
- Nerd Font workspace icons
- Wallbash color integration from HyDE

---

### File Management

#### Dolphin (`configs/dolphin/`) - KDE File Manager
Feature-rich file manager for Arch Linux:

**View Settings:**
- Details mode with 64px preview icons
- Split view enabled, hidden files visible
- Full path in address bar (editable)
- Expandable folders, filter bar, zoom slider

**Service Menus** (right-click actions):
- Git integration via dolphin-plugins
- Copy path via wl-clipboard (Wayland)
- Custom `.desktop` actions

---

### AI Development

#### Claude Code (`configs/claude/`)
Claude Code IDE settings and configuration.

#### AI Rules (`configs/ai-rules/`)
Context rules for AI coding assistants:

| Directory | Tool | Contents |
|-----------|------|----------|
| `cursor-rules/` | Cursor IDE | cursor_rules.mdc, dev_workflow.mdc, nextjs.mdc, taskmaster.mdc |
| `aider-rules/` | Aider | Framework-specific guidance (TypeScript, Next.js, NestJS, Django) |
| `avante-rules/` | Avante | Planning workflow rules |

---

### Additional Configs

| Directory | Purpose |
|-----------|---------|
| `configs/git/` | `.gitconfig.template`, `.gitignore_global`, work.gitconfig |
| `configs/bat/` | Syntax highlighting for cat replacement |
| `configs/brave/` | Browser customization |
| `configs/codex/` | Codex AI integration |
| `configs/opencode/` | OpenCode settings |
| `configs/fastfetch/` | System info display |
| `configs/pyright/` | Python type checking |
| `configs/i3/` | i3 window manager (Fedora) |
| `configs/sway/` | Sway compositor |
| `configs/glazeWM/` | GlazeWM (Windows) |
| `configs/man/` | Custom man pages for dotfiles |

---

## Platform Profiles

### macOS (`mac`)

```bash
./bin/dot --system mac
```

**Installs:** Git, Zsh, Neovim nightly, Node, Tmux+TPM, Fonts, Starship, Ghostty, LazyGit, Claude/Codex/OpenCode, Fastfetch, Brave

**Work variant** (`mac_work`): Adds Homebrew apps + Aerospace + enterprise tools

### Arch Linux (`linux_arch`)

```bash
./bin/dot --system linux_arch
```

**Installs:** Pacman packages, Git, Node, LazyGit, Zsh, Vim, Tmux, Bat, Ghostty, Fonts, Starship, Fastfetch, Brave, Docker, Claude/Codex, Dolphin, HyDE

**Pacman packages:** zsh, starship, tmux, ripgrep, eza, zoxide, wl-clipboard, fzf, jq, bat, dysk, htop, btop, ttf-jetbrains-mono-nerd, mangohud, darktable, podman, yubikey-manager, github-cli

### Ubuntu (`linux_ubuntu`)

```bash
./bin/dot --system linux_ubuntu
```

**Installs:** Core dev tools via apt, Node, LazyGit, Starship, Fastfetch, Wezterm (Windows-compatible)

### Fedora (`linux_fedora`)

```bash
./bin/dot --system linux_fedora
```

**Installs:** i3wm, Polybar, LazyGit, Fonts, Starship, Fastfetch

---

## Architecture

```
dotfiles/
├── cmd/otobun/main.go         # Go TUI entry point
├── internal/                   # Go packages
│   ├── config/                # .dotconfig read/write
│   ├── detector/              # OS/platform detection
│   ├── installer/             # Component parsing & script runner
│   └── tui/                   # Bubble Tea screens
│       ├── wizard/            # Setup wizard (Huh? forms)
│       ├── selector/          # Module checkbox selector
│       ├── runner/            # Installation progress view
│       └── theme/             # Lip Gloss brand styles
├── bin/
│   ├── dot                    # Legacy shell management CLI
│   └── otobun                 # Compiled Go TUI binary (gitignored)
├── boot.sh                    # Remote bootstrap script
├── bootstrap.sh               # Legacy installation
├── script/
│   ├── common/
│   │   ├── log.sh            # Logging utilities (section, step, info, success, fail)
│   │   └── symlink.sh        # Symlink with conflict resolution ([O]verride/[B]ackup/[S]kip)
│   ├── *_installation.sh     # Platform installers (mac, linux_arch, etc.)
│   └── {component}/          # Component setup scripts
│       └── {platform}/setup.sh
├── configs/                   # Configuration files (symlinked to home)
│   ├── aerospace/            # macOS tiling WM + sketchybar
│   ├── nvim/                 # Neovim + LazyVim
│   ├── tmux/                 # Tmux + custom scripts
│   ├── zshrc/                # Zsh + modular configs
│   ├── hypr/                 # Hyprland (Arch)
│   ├── waybar/               # Wayland status bar
│   ├── dolphin/              # KDE file manager
│   ├── ghostty/              # Terminal emulator
│   ├── starship/             # Shell prompt
│   ├── lazygit/              # Git TUI
│   ├── ai-rules/             # AI assistant rules
│   └── ...
├── go.mod                     # Go module definition
└── .dotconfig                 # User preferences (auto-generated)
```

### Configuration Management

User preferences stored in `.dotconfig`:
```bash
DOT_NAME="Jordan Garcia"
DOT_EMAIL="user@example.com"
DOT_ENVIRONMENT="work|personal"
DOT_SYSTEM="mac|linux_arch|..."
DOT_YUBIKEY="ABC123..."  # Optional GPG key for git signing
```

---

## Management Commands

### otobun (Go TUI)

```bash
otobun                    # Full TUI: wizard → module selector → installer
otobun --setup            # Force setup wizard (even if .dotconfig exists)
otobun --config           # Show current configuration
otobun --system           # Show detected system
otobun --help             # Show help
```

### bin/dot (Legacy Shell)

```bash
./bin/dot -h              # Show help
./bin/dot -i              # Interactive setup
./bin/dot -l              # List available profiles
./bin/dot -m              # Select modules interactively
./bin/dot -s              # Show system detection
./bin/dot -c              # View current config
./bin/dot -e              # Open dotfiles in $EDITOR
./bin/dot --reset-config  # Clear config and start fresh
./bin/dot --reconfigure   # Re-run interactive setup
```

---

## Post-Installation

### Tmux Plugins
```bash
tmux source ~/.tmux.conf   # Reload config
# Inside tmux: <prefix> + I to install plugins
```

### Zsh Plugins
Plugins are sourced directly from `~/.zsh/plugins/`. Install via git clone:
```bash
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/plugins/zsh-autosuggestions
```

### YubiKey Git Signing (Optional)
```bash
gpg --list-secret-keys --keyid-format=long  # Find key ID
# Provide during ./bin/dot -i or set manually
```

---

## Development

### Building otobun

```bash
# Requires Go 1.22+
go build -o bin/otobun ./cmd/otobun

# Run tests
go test ./...

# Cross-compile
GOOS=darwin GOARCH=arm64 go build -o bin/otobun-darwin-arm64 ./cmd/otobun
GOOS=linux GOARCH=amd64 go build -o bin/otobun-linux-amd64 ./cmd/otobun
```

### Adding Components

1. Create setup script: `script/{component}/{platform}/setup.sh`
2. Add to installation array in `script/{platform}_installation.sh`
3. Use logging from `script/common/log.sh`
4. Place configs in `configs/{component}/`
5. The `otobun` TUI automatically picks up new components from the installation arrays

### Supporting New Platforms

1. Add detection to `internal/detector/system.go` (Go) and `bin/dot` `detect_system()` (shell)
2. Create `script/{platform}_installation.sh`
3. Implement component scripts
4. Choose package manager (brew/apt/dnf/pacman)

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Permission denied | Don't run with `sudo` - scripts handle elevation |
| Missing dependencies | Run platform installation script first |
| Config conflicts | `./bin/dot --reset-config` to start fresh |
| Tmux plugins missing | Inside tmux: `<prefix> + I` |

---

_Tested across macOS, Arch Linux, Ubuntu, Fedora, and WSL. Fork and adapt for your needs._
