# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

**otobun** - Opinionated, cross-platform dotfiles supporting macOS, Linux (Fedora, Ubuntu, Arch), and WSL with personal/work environment configurations. Uses a modular, script-based architecture with symlink-based configuration management.

## Key Commands

### Installation & Setup
```bash
# Remote installation (YOLO method)
curl -fsSL https://raw.githubusercontent.com/whoisjordangarcia/dotfiles/main/boot.sh | bash

# Interactive setup (recommended for first-time)
./bin/dot -i

# Direct installation with explicit configuration
./bin/dot --system mac --work          # Mac work environment
./bin/dot --system linux_ubuntu --personal

# Legacy method
./bootstrap.sh
```

### Management Commands
```bash
./bin/dot -l              # List available installation profiles
./bin/dot -s              # Show system detection results
./bin/dot -c              # Display current configuration
./bin/dot --reset-config  # Clear configuration and start over
./bin/dot --reconfigure   # Re-run interactive setup
./bin/dot -e              # Open dotfiles in $EDITOR
```

### Component-Level Installation
Individual components can be installed directly:
```bash
./script/zsh/setup.sh
./script/tmux/setup.sh
./script/lazygit/mac/setup.sh
./script/apps/mac/setup.sh        # Homebrew package management
./script/fonts/mac/setup.sh
./script/neovim/mac/setup.sh
```

## Architecture

### Entry Points & Installation Flow
1. **Remote Bootstrap**: `boot.sh` - Clones repo, fetches updates, launches interactive setup
2. **CLI Tool**: `bin/dot` - Main management interface with system detection and configuration
3. **Legacy**: `bootstrap.sh` - Original installation script (maintained for compatibility)

### Directory Structure
```
bin/dot                           # Enhanced CLI with interactive setup
script/
  ├── common/
  │   ├── log.sh                 # Logging utilities (info, success, fail, etc.)
  │   └── symlink.sh             # Symlink creation with override/backup prompts
  ├── {platform}_installation.sh # Platform installers (mac, linux_ubuntu, etc.)
  └── {component}/{platform}/setup.sh  # Component-specific setup scripts
configs/                          # Configuration files (symlinked to home)
  ├── nvim/                      # Neovim with LazyVim
  ├── tmux/                      # Tmux with TPM plugins
  ├── zshrc/                     # Zsh configuration and modules
  ├── hypr/                      # Hyprland (Arch)
  ├── aerospace/                 # Aerospace window manager (macOS)
  └── ai-rules/                  # AI assistant rules (Cursor, Aider, Avante)
.dotconfig                        # Generated config file (DOT_NAME, DOT_EMAIL, etc.)
```

### Configuration Management System

**Persistent Configuration** (`.dotconfig`):
```bash
DOT_NAME="Jordan Garcia"           # User's full name
DOT_EMAIL="user@example.com"       # Git email address
DOT_ENVIRONMENT="work|personal"    # Environment type
DOT_SYSTEM="mac|linux_ubuntu|..."  # Installation profile
DOT_YUBIKEY="ABC123..."            # GPG key ID for git signing (optional)
```

**Environment Variables** (exported during installation):
- `$WORK_ENV` - Set to "1" when `DOT_ENVIRONMENT="work"`
- All `DOT_*` variables exported for component scripts

**Environment Auto-Detection Logic**:
1. Check git config email for `@labcorp.com` → work environment
2. Check `WORK_ENV` or `--work` flag → work environment
3. Default → personal environment

### Platform Detection

**System Detection** (`detect_system()` in bin/dot:23):
- macOS: `$OSTYPE == "darwin"*` → `mac`
- Linux: Parse `/etc/os-release` → `linux_ubuntu`, `linux_fedora`, `linux_arch`
- Maps to installation scripts: `script/{detected}_installation.sh`

**Auto-Selection Logic**:
1. Exact match: `linux_ubuntu` → `script/linux_ubuntu_installation.sh`
2. Partial match: `mac` → first `mac*` installation script
3. Work variant: `mac` + work env → `script/mac_work_installation.sh` (if exists)

### Brewfile Management (macOS Only)

**Brewfile Selection** (script/apps/mac/setup.sh:52-74):
1. Install `Brewfile.base` (core packages for all environments)
2. Install environment-specific:
   - `Brewfile.work` - Work environment packages
   - `Brewfile.personal` - Personal environment packages
   - `Brewfile.legacy` - Fallback if environment-specific not found

**Work Environment Detection**:
- Email contains `@labcorp.com`
- `--work` flag passed to `./bin/dot`
- `WORK_ENV` environment variable set

### Symlink Architecture

**Core Principle**: Configs are symlinked (not copied) from `configs/` to their standard locations, enabling centralized version control.

**Symlink Utility** (`script/common/symlink.sh:6`):
```bash
link_file "$SOURCE" "$TARGET"
```

**Conflict Resolution** (interactive prompts):
- **[O]verride**: Remove existing file/symlink, create new symlink
- **[B]ackup**: Rename to `{file}_YYYYMMDD.bak`, create new symlink
- **[S]kip**: Keep existing file/symlink unchanged

**Common Symlink Patterns**:
```bash
# Direct file symlink (zsh, tmux)
link_file "$SCRIPT_DIR/../../configs/zshrc/.zshrc" "$HOME/.zshrc"

# Directory symlink (tmux scripts)
link_file "$SCRIPT_DIR/../../configs/tmux/scripts" "$HOME/.tmux/scripts"
```

### Component Installation Pattern

**Standard Structure** (all component setup scripts):
```bash
#!/bin/bash
set -euo pipefail  # Strict error handling

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# Source utilities
source "$SCRIPT_DIR/../common/log.sh"       # Logging functions
source "$SCRIPT_DIR/../common/symlink.sh"   # Symlink utility (if needed)

# Install dependencies (check before installing)
if ! command -v tool &>/dev/null; then
    info "Installing tool..."
    # Installation logic
fi

# Create symlinks
link_file "$SOURCE" "$TARGET"

# Post-installation tasks
```

**Platform-Specific Scripts**:
- Location: `script/{component}/{platform}/setup.sh`
- Platform: `mac/`, `linux/`, `fedora/`, `ubuntu/`, `arch/`
- Example: `script/lazygit/mac/setup.sh`, `script/hypr/linux/setup.sh`

**Installation Array Pattern** (script/mac_installation.sh:7):
```bash
component_installation=(
    git
    zsh
    vim
    neovim/mac    # Platform-specific path
    tmux
    fonts/mac
)

for component in "${component_installation[@]}"; do
    section "$component"
    script_path="./script/${component}/setup.sh"
    if [ -f "$script_path" ]; then
        source "$script_path"  # Execute in same shell to share env vars
    fi
done
```

### Logging System

**Log Functions** (`script/common/log.sh`):
```bash
section "Installing Zsh"    # Major installation phase (blue ▶)
step "Linking .zshrc"       # Individual component step (•)
info "Message"              # General information
success "Done!"             # Success message (green OK)
fail "Error message"        # Error and exit (red FAIL)
debug "Debug info"          # Debug output (respects LOG_LEVEL)
prompt "Name: "             # Interactive prompt (blue ▶)
header "Setup Complete"     # Section header (━━━)
```

**Log Level Control**:
```bash
export LOG_LEVEL=debug    # Show all messages (debug, info, warn, error)
export LOG_LEVEL=info     # Default (info, warn, error)
export LOG_LEVEL=error    # Only errors
```

## Development Patterns

### Adding New Components

1. **Create platform-specific setup script**:
   ```bash
   mkdir -p script/{component}/{platform}
   touch script/{component}/{platform}/setup.sh
   chmod +x script/{component}/{platform}/setup.sh
   ```

2. **Follow standard structure** (see Component Installation Pattern above)

3. **Add to installation array** in `script/{platform}_installation.sh`:
   ```bash
   component_installation=(
       # ... existing components
       {component}/{platform}  # Add here
   )
   ```

4. **Place configs** in `configs/{component}/` for symlinking

### Supporting New Platforms

1. **Add detection** to `bin/dot` `detect_system()` function
2. **Create installer**: `script/{platform}_installation.sh`
3. **Implement component scripts**: `script/{component}/{platform}/setup.sh`
4. **Choose package manager**: brew (macOS), apt (Ubuntu), dnf (Fedora), pacman (Arch)

### Script Guidelines

- **Always source logging**: `source "$SCRIPT_DIR/../common/log.sh"`
- **Use strict mode**: `set -euo pipefail` for safety
- **Check before installing**: Detect if tools/files already exist
- **Preserve permissions**: `chmod 600 ~/.zshrc` for sensitive configs
- **Export for sub-scripts**: Configuration vars must be exported for sourced scripts

### YubiKey Git Signing Setup

GPG signing configuration for commits (optional):
```bash
# During interactive setup, provide YubiKey ID
./bin/dot -i  # Will prompt for YubiKey ID

# Or configure manually
gpg --list-secret-keys --keyid-format=long  # Find your key ID
git config --global user.signingkey YOUR_KEY_ID
git config --global commit.gpgsign true
```

## Platform-Specific Notes

### macOS
- **Window Manager**: Aerospace with Sketchybar integration
- **Terminal**: Ghostty (replaces Alacritty/Kitty)
- **Brewfile**: Environment-aware (work/personal package lists)
- **System Tweaks**: Disables press-and-hold, sets Screenshots folder

### Arch Linux
- **Window Manager**: Hyprland with HyDE theme
- **Display**: Waybar panel, Rofi launcher (Wayland)
- **T2 MacBook Support**: Requires manual `apple-bce` driver installation
- **Kernel**: Use `linux-t2` for MacBook hardware compatibility

### Fedora
- **Window Manager**: i3wm
- **Display**: Polybar panel
- **Terminal**: Wezterm

### Ubuntu
- **Desktop**: GNOME with extensions
- **Terminal**: GNOME Terminal or Wezterm

### WSL
- **Wezterm**: Copy `configs/wezterm/wezterm.lua` to `C:/Users/{username}/.wezterm.lua`
- Cross-platform file access considerations

## Post-Installation Manual Steps

### Tmux Plugin Installation
```bash
# Reload tmux config
tmux source ~/.tmux.conf

# Install plugins (inside tmux)
<prefix> + I    # Default prefix is Ctrl+b, then press I
```

### Shell Integration
```bash
# Add to .zshrc if not already present
source <(fzf --zsh)    # FZF keybindings
```

### AI Rules
AI assistant rules in `configs/ai-rules/`:
- **Cursor**: `.mdc` format rules with file patterns
- **Aider**: Framework-specific guidance (TypeScript, Next.js, NestJS, Django)
- **Avante**: Planning workflow rules
- add to memory