# Jordan's dotfiles

# What will be installed?

- iterm2 w/ dracula theme (mac only)
- oh-my-zsh
- dotfiles
- powerlevel10k
- Fira Code + MesloLGS NF fonts

## Quick setup (for Mac)

1. Install homebrew 

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

2. Install iTerm2 - `brew install --cask iterm2`

3. Open iTerm2 > Menu > Make iTerm2 Default Term

4. ~/git git clone https://github.com/dracula/iterm.git

5. iTerm2 > Preferences > Profiles > Colors Tab
   Open the Color Presets... drop-down in the bottom right corner
   Select Import... from the list
   Select the Dracula.itermcolors file
   Select the Dracula from Color Presets...

6. Install gh cli `brew install gh`

7. Install nvm `brew install nvm`

8. Install `brew install zsh`

9. Install powerlevel10k

```
brew install romkatv/powerlevel10k/powerlevel10k echo "source $(brew --prefix)/opt/powerlevel10k/powerlevel10k.zsh-theme" >>~/.zshrc
```

## Continue for Ubuntu Windows 

6, Install zsh (Ubuntu)

```
apt install zsh
```

7. Install oh-my-zsh 

```
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

8. Install powerlevel10k (Ubuntu)

```
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
```

9. Install nvm (Ubuntu)
```
curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
source ~/.zshrc
```


10. `sudo chsh -s $(which zsh)` default zsh

11. sudo git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

12. sudo git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

13. Update .zshrc file with `plugins=( [plugins...] zsh-syntax-highlighting zsh-autosuggestions)`

source ~/.zshrc

13. Mac: brew install lolcat

14. Mac: brew install figlet

## (WSL) Ubuntu issues

- chmod issues (https://alessandrococco.com/2021/01/wsl-how-to-resolve-operation-not-permitted-error-on-cloning-a-git-repository)
