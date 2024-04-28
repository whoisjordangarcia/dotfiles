# Jordan's dotfiles

Started to organize my dotfiles, it uses symlinks (will try stow or nix in the future_. My dotfiles are compatible for Fedora, Ubuntu, MacOS. This allows me to have the same devex on my main Windows 11 PC using WSL2, Personal laptop using Fedora, Work laptop using MacOS. Feel free in trying it out yourself.

# What will be installed?

- zsh w/ oh-my-zsh
- zsh plugins:
   - zsh-syntax-highlighting 
   - zsh-autosuggestions
- neovim
- powerlevel10k
- tmux
- ripgrep
- autojump
- eza
- lolcat/figlet

## Installation

```
./bootstrap.sh

1. tmux source ~/.tmux.conf
2. Install plugins with prefix + I <C-b> I
```


