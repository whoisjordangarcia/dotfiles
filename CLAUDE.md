# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a comprehensive dotfiles repository that supports multiple platforms (macOS, Linux distributions: Fedora, Ubuntu, Arch) with both personal and work environment configurations. It uses a modular, script-based architecture for cross-platform compatibility.

## Key Commands

### Main Installation & Management
```bash
# Interactive setup with system detection
./bin/dot -i

# Direct installation commands  
./bin/dot --system mac --work      # Mac work environment
./bin/dot --system linux_ubuntu    # Ubuntu installation
./bootstrap.sh                     # Legacy bootstrap method

# Management commands
./bin/dot -l                       # List available installations
./bin/dot -s                       # Show system detection
./bin/dot -c                       # Show current configuration
./bin/dot --reset-config           # Reset configuration
```

### Platform-Specific Installation
```bash
# Mac
./script/mac_installation.sh

# Linux variants
./script/linux_fedora_installation.sh
./script/linux_ubuntu_installation.sh
./script/linux_arch_installation.sh
```

### Component Setup
Individual components can be installed via their setup scripts:
```bash
./script/zsh/setup.sh
./script/tmux/setup.sh  
./script/lazygit/mac/setup.sh
./script/apps/mac/setup.sh        # Homebrew packages
./script/fonts/mac/setup.sh
```

## Architecture & Code Structure

### Core Architecture
- **Entry Points**: `bin/dot` (enhanced) and `bootstrap.sh` (legacy) - both detect platform and launch appropriate installation
- **Installation Scripts**: Platform-specific scripts in `script/` directory following naming pattern `{platform}_{distro}_installation.sh`
- **Component Scripts**: Modular setup scripts in `script/{component}/{platform}/setup.sh` structure
- **Configuration Management**: `.dotconfig` file stores user preferences (name, email, environment type)

### Key Directories
- `bin/`: Enhanced dotfiles management CLI
- `script/`: All installation and setup scripts organized by component and platform
- `configs/`: Configuration files for various tools (nvim, tmux, zsh, etc.)
- `configs/ai-rules/`: AI assistant rules for different frameworks and workflows

### Environment Detection & Configuration
The system automatically detects:
- Operating system (Darwin/Linux) 
- Linux distribution (Ubuntu/Fedora/Arch via `/etc/os-release`)
- Work vs personal environment (via git config email domain or explicit flags)
- Appropriate Brewfile selection (base + environment-specific packages on Mac)

### Brewfile Management (macOS)
- `Brewfile.base`: Core packages for all environments
- `Brewfile.personal`: Personal environment packages  
- `Brewfile.work`: Work environment packages
- `Brewfile.legacy`: Fallback for older setups
- Environment detected via `@labcorp.com` email domain or `--work` flag

### Configuration Symlinks
The system creates symlinks from repository configs to their expected locations rather than copying files, allowing centralized management.

## Development Patterns

### Script Structure
- All scripts source `script/common/log.sh` for consistent logging (info, success, error functions)
- Platform detection using `$OSTYPE` and `/etc/os-release`
- Environment variables: `DOT_NAME`, `DOT_EMAIL`, `DOT_ENVIRONMENT`, `DOT_SYSTEM`, `WORK_ENV`
- Homebrew installation handled in `script/apps/mac/setup.sh`

### Adding New Components
1. Create platform-specific setup script: `script/{component}/{platform}/setup.sh`
2. Add component to appropriate installation array in platform installation script
3. Follow existing pattern of conditional installation based on file existence

### Multi-Platform Support
- Use platform-specific subdirectories: `mac/`, `linux/`, `fedora/`, `ubuntu/`
- Check for platform compatibility before running platform-specific commands
- Leverage distribution package managers appropriately (brew, apt, dnf, pacman)

## AI Rules Integration
This repository includes extensive AI rules in `configs/ai-rules/` for:
- Cursor IDE rules (`.mdc` format)
- Aider rules (framework-specific guidance)  
- Avante rules (planning workflows)
- Covers TypeScript, Next.js, NestJS, Django frameworks

The AI rules follow structured formats with descriptions, file glob patterns, and specific guidance for maintaining consistency across different AI coding assistants.