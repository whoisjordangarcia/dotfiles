# Jordan's dotfiles

# What will be installed?

- iterm2 w/ dracula theme
- oh-my-zsh
- dotfiles
- powerlevel10k
- Fira Code + MesloLGS NF fonts

## Quick setup

1. Install homebrew - `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

2. Install iTerm2 - `brew install --cask iterm2`

3. Open iTerm2 > Menu > Make iTerm2 Default Term

4. ~/git git clone https://github.com/dracula/iterm.git

5. iTerm2 > Preferences > Profiles > Colors Tab
   Open the Color Presets... drop-down in the bottom right corner
   Select Import... from the list
   Select the Dracula.itermcolors file
   Select the Dracula from Color Presets...

6. Install zsh - `sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"`

7. Install powerlevel10k - `brew install romkatv/powerlevel10k/powerlevel10k echo "source $(brew --prefix)/opt/powerlevel10k/powerlevel10k.zsh-theme" >>~/.zshrc`

8. Install gh cli `brew install gh`

9, Install nvm `brew install nvm`