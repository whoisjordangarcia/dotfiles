# Jordan's dotfiles

Started to organize my dotfiles, it uses symlinks future. My dotfiles are compatible for Arch, Fedora, Ubuntu, MacOS. This allows me to have the same devex on my main Windows 11 PC using WSL2, Personal laptop using ~Fedora~Arch Btw, Work laptop using MacOS. Feel free in trying it out yourself.

# What will be installed?

- zsh / oh-my-zsh
- zsh plugins:
  - zsh-syntax-highlighting
  - zsh-autosuggestions
- neovim, lazyvim
- tmux
- ripgrep
- eza
- zoxide
- lolcat/figlet

## Installation

Don't prefix with sudo

```bash
./bootstrap.sh

1. tmux source ~/.tmux.conf
2. Install plugins with prefix + I <C-b> I
3. ~p10k configure~
4. source <(fzf --zsh)
```

## MacOS

- **Terminal** ~iterm2~ ~[wezterm](https://github.com/wez/wezterm)~ [ghostty](https://ghostty.org/)
- **Window Manager** aerospace, sketchybar
- **Panel** sketchybar
- **Shell prompt** ~powerline10k~ starship

## ArchBtw

- **OS** • [T2Linux](https://wiki.t2linux.org/)
- **Window Manager** • [Hyprland](https://github.com/hyprwm/Hyprland)
- **Shell** • [Zsh](https://www.zsh.org) [powerline10k](https://github.com/romkatv/powerlevel10k)
- **Terminal** • ~[Wezterm](https://github.com/wez/wezterm)~ [Ghostty](https://ghostty.org/)
- **Panel** • [Waybar](https://github.com/Alexays/Waybar)
- **Launcher** • [Rofi Wayland](https://wiki.archlinux.org/title/Rofi)
- **File Manager** • [Dolphin](https://kde.org/applications/system/org.kde.dolphin/)
- "Theme" • [HyDE](https://github.com/HyDE-Project/HyDE)

### Tips for Arch

1.  `apple-bce` requires manual `make` installation - <https://github.com/t2linux/apple-bce-drv>
2.  Install 1password `https://support.1password.com/install-linux/#arch-linux`
3.  Ensure systemd is using linux-t2
4.  Had a bug in HyDE where I couldn't open Rofi via keybindings. This was due to locale not been set.

## Notes for Fedora

- **Window Manager** • [i3-wm](https://github.com/i3/i3)
- **Shell** • [Zsh](https://www.zsh.org) [powerline10k](https://github.com/romkatv/powerlevel10k)
- **Terminal** • [Wezterm](https://github.com/wez/wezterm)
- **Panel** • [Polybar](https://github.com/polybar/polybar)

## Notes for WSL

- Copy wezterm.lua under Windows home directory (C:/Users/jordan/.wezterm.lua)
- Tmux configuration requires updating

## iOS

- **OS** a-Shell
