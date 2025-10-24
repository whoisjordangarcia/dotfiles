# dotfiles - Otobun

**Opinionated, curated dotfiles for the discerning developer**

otobun is a comprehensive cross-platform dotfiles repository that makes strong choices about your development environment. Supporting macOS, Linux (Ubuntu, Fedora, Arch), and WSL with both personal and work configurations, it's designed for developers who want a thoughtfully curated setup without the decision fatigue.

> **Why "otobun"?** These dotfiles are opinionated ("oto" from opinionated) and bundled ("bun") together as a cohesive package. No endless options—just curated choices that work across multiple platforms.

## Features

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

### yolo it

```bash
curl -fsSL https://raw.githubusercontent.com/whoisjordangarcia/dotfiles/main/boot.sh | bash
```

This will automatically:

- Clone or update the dotfiles repository
- Fetch the latest changes
- Run the interactive setup process

### Interactive Installation (Recommended)

```bash
# Clone the repository
git clone https://github.com/yourusername/dotfiles.git
cd dotfiles

# Run interactive setup
./bin/dot -i
```

The interactive setup will:

- Detect your system automatically
- Configure your name and email
- Choose between personal/work environments
- Install appropriate packages and configurations

### Direct Installation

For automated setups or CI/CD:

```bash
# macOS work environment
./bin/dot --system mac --work

# Ubuntu personal environment
./bin/dot --system linux_ubuntu --personal

# Use legacy bootstrap method
./bootstrap.sh
```

## What Gets Installed

### Core Tools

- **Shell**: Zsh with Oh My Zsh, syntax highlighting, and autosuggestions
- **Editor**: Neovim with LazyVim configuration
- **Terminal Multiplexer**: Tmux with custom configuration
- **File Navigation**: eza, zoxide, ripgrep, fzf
- **Prompt**: Starship (cross-platform) or Powerlevel10k

### Platform-Specific Applications

#### macOS

- **Terminal**: Ghostty
- **Window Manager**: Aerospace with Sketchybar
- **Package Manager**: Homebrew with curated package lists
- Environment-specific Brewfiles (personal/work)

#### Arch Linux

- **Window Manager**: Hyprland with HyDE theme
- **Terminal**: Ghostty
- **Panel**: Waybar
- **Launcher**: Rofi (Wayland)
- **File Manager**: Dolphin

#### Fedora

- **Window Manager**: i3wm
- **Terminal**: Wezterm
- **Panel**: Polybar

#### Ubuntu

- **Desktop Environment**: GNOME with extensions
- **Terminal**: GNOME Terminal or Wezterm

## Management Commands

```bash
# Show help and available options
./bin/dot --help

# List all available installations
./bin/dot --list

# Show current system detection
./bin/dot --system

# View current configuration
./bin/dot --config

# Reset configuration and start over
./bin/dot --reset-config

# Open dotfiles in editor
./bin/dot --edit
```

## Architecture

### Directory Structure

```
dotfiles/
├── bin/dot                    # Enhanced management CLI
├── bootstrap.sh              # Legacy installation script
├── script/                   # Installation and setup scripts
│   ├── common/              # Shared utilities
│   ├── *_installation.sh    # Platform-specific installers
│   └── {component}/         # Component setup scripts
├── configs/                 # Configuration files
│   ├── nvim/               # Neovim configuration
│   ├── hypr/               # Hyprland configuration
│   ├── ai-rules/           # AI assistant rules
│   └── ...                 # Other tool configs
└── .dotconfig              # User preferences (auto-generated)
```

### Environment Detection

The system automatically detects:

- **Operating System**: macOS (Darwin) or Linux distributions
- **Linux Distribution**: Ubuntu, Fedora, or Arch via `/etc/os-release`
- **Environment Type**: Work (via `@labcorp.com` email) or personal
- **Available Components**: Based on platform compatibility

### Configuration Management

User preferences are stored in `.dotconfig`:

- Full name and email address
- Environment type (personal/work)
- Selected installation profile
- System detection results

## Platform Notes

### macOS Setup

Work environments automatically use `Brewfile.work` with enterprise tools, while personal setups use `Brewfile.personal`. The system detects work environments by email domain or explicit flags.

### Arch Linux

Includes T2Linux support for MacBook hardware. Install `apple-bce` driver manually and ensure systemd uses `linux-t2` kernel.

### WSL Configuration

Copy `wezterm.lua` to Windows home directory (`C:/Users/username/.wezterm.lua`) for proper terminal integration.

## Development

### Adding New Components

1. Create setup script: `script/{component}/{platform}/setup.sh`
2. Add to platform installation array in `script/{platform}_installation.sh`
3. Follow existing logging patterns using `script/common/log.sh`

### Supporting New Platforms

1. Add system detection logic to `bin/dot`
2. Create `script/{platform}_installation.sh`
3. Implement platform-specific component scripts
4. Test across different environments

## Troubleshooting

### Common Issues

**Permission denied**: Don't run with `sudo` - the scripts handle elevation when needed

**Missing dependencies**: Run the appropriate installation script for your platform first
**Configuration conflicts**: Use `./bin/dot --reset-config` to start fresh

### Manual Steps

After installation, you may need to:

1. Source tmux configuration: `tmux source ~/.tmux.conf`
2. Install tmux plugins: `<prefix> + I` (Ctrl+b, then I)
3. Configure shell integrations: `source <(fzf --zsh)`

---

_This dotfiles setup has been tested across multiple platforms and environments. Feel free to fork and adapt for your own needs._
