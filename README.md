# Jordan's dotfiles

A cross-platform dotfiles configuration that provides a consistent development experience across multiple operating systems including Arch Linux, Fedora, Ubuntu, macOS, and Windows (WSL2).

## 🚀 Features

- Unified development environment across different platforms
- Modular configuration using symlinks
- Support for multiple operating systems
- Modern terminal and development tools

## 📦 Core Components

- **Shell**: Zsh with Oh-my-zsh
- **Terminal Multiplexer**: Tmux
- **Editor**: Neovim with LazyVim
- **Modern CLI Tools**:
  - ripgrep (fast search)
  - eza (modern ls replacement)
  - zoxide (smart directory navigation)
  - fzf (fuzzy finder)
  - lolcat/figlet (terminal styling)

### Zsh Plugins

- zsh-syntax-highlighting
- zsh-autosuggestions

## 🛠 Installation

```bash
# Clone the repository
git clone https://github.com/jordan.garcia/dotfiles.git
cd dotfiles

# Run the bootstrap script (do not use sudo)
./bootstrap.sh
```

### Post-Installation Steps

1. Load tmux configuration:

   ```bash
   tmux source ~/.tmux.conf
   ```

2. Install tmux plugins:

   - Press `<C-b> I` (Ctrl+B, then Shift+I)

3. Initialize fzf:
   ```bash
   source <(fzf --zsh)
   ```

## 💻 Platform-Specific Configurations

### macOS

- **Terminal**: [Ghostty](https://ghostty.org/)
- **Window Manager**: Aerospace
- **Status Bar**: Sketchybar
- **Shell Prompt**: Starship

### Arch Linux

- **Base**: [T2Linux](https://wiki.t2linux.org/)
- **Window Manager**: [Hyprland](https://github.com/hyprwm/Hyprland)
- **Terminal**: [Ghostty](https://ghostty.org/)
- **Panel**: [Waybar](https://github.com/Alexays/Waybar)
- **Launcher**: [Rofi Wayland](https://wiki.archlinux.org/title/Rofi)
- **File Manager**: [Dolphin](https://kde.org/applications/system/org.kde.dolphin/)
- **Theme**: [HyDE](https://github.com/HyDE-Project/HyDE)

#### Arch Setup Notes

1. Manual installation required for `apple-bce`: [Instructions](https://github.com/t2linux/apple-bce-drv)
2. Install 1Password: [Arch Linux Instructions](https://support.1password.com/install-linux/#arch-linux)
3. Verify systemd is using linux-t2
4. Note: If Rofi keybindings don't work in HyDE, check locale settings

### Fedora

- **Window Manager**: [i3-wm](https://github.com/i3/i3)
- **Terminal**: [Wezterm](https://github.com/wez/wezterm)
- **Panel**: [Polybar](https://github.com/polybar/polybar)

### Windows (WSL)

1. Copy wezterm.lua to Windows home directory: `C:/Users/jordan/.wezterm.lua`
2. Note: Tmux configuration may need adjustments

### iOS

- Compatible with a-Shell

## 🤝 Contributing

Feel free to try it out and contribute improvements! Issues and pull requests are welcome.

## 📝 License

This project is open source and available under the MIT License.
