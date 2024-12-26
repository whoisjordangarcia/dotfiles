# Jordan's dotfiles

Started to organize my dotfiles, it uses symlinks (will try stow or nix in the future). My dotfiles are compatible for Arch, Fedora, Ubuntu, MacOS. This allows me to have the same devex on my main Windows 11 PC using WSL2, Personal laptop using ~Fedora~Arch Btw, Work laptop using MacOS. Feel free in trying it out yourself.

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

```
./bootstrap.sh

1. tmux source ~/.tmux.conf
2. Install plugins with prefix + I <C-b> I
3. ~p10k configure~
4. source <(fzf --zsh)
```

## MacOS

- **Terminal** ~iterm2~ [wezterm](https://github.com/wez/wezterm)
- **Window Manager** aerospace, sketchybar
- **Panel** sketchybar
- **Shell prompt** ~powerline10k~ starship

## ArchBtw

- **OS** • [T2Linux]()
- **Window Manager** • [Hyprland](https://github.com/hyprwm/Hyprland)
- **Shell** • [Zsh](https://www.zsh.org) [powerline10k](https://github.com/romkatv/powerlevel10k)
- **Terminal** • [Wezterm](https://github.com/wez/wezterm)
- **Panel** • [Waybar]
- **Launcher** • [Rofi]()
- **File Manager** • [Dolphin]()

### Tips for Arch

1. `apple-bce` requires manual `make` installation - https://github.com/t2linux/apple-bce-drv
2. Install 1password `https://support.1password.com/install-linux/#arch-linux`
3. Ensure systemd is using linux-t2

## Notes for Fedora

- **Window Manager** • [i3-wm](https://github.com/i3/i3)
- **Shell** • [Zsh](https://www.zsh.org) [powerline10k](https://github.com/romkatv/powerlevel10k)
- **Terminal** • [Wezterm](https://github.com/wez/wezterm)
- **Panel** • [Polybar](https://github.com/polybar/polybar)

## Notes for WSL

- Copy wezterm.lua under Windows home directory (C:/Users/jordan/.wezterm.lua)
- Tmux configuration requires updating

## To try out in the future

- [ ] Dunst - notify daemon
- [ ] Ranger - launcher
- [ ] nvchad - gui ide
- [x] starship - shell

## Notes for Windows

- starship installation
