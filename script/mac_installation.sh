# Fail on any command.
set -eux pipefail

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install iTerm2 
brew install --cask iterm2

mkdir ~/git

(cd ~/git && git https://github.com/dracula/iterm.git)

# Install Github CLI
brew install gh

# Install NVM
brew install nvm

# Install zsh 
brew install zsh

# Install powerlevel10k
brew install romkatv/powerlevel10k/powerlevel10k echo "source $(brew --prefix)/opt/powerlevel10k/powerlevel10k.zsh-theme" >>~/.zshrc

# Install lolcat
brew install lolcat

# Install figlet
brewq install figlet

# Override the config for .zshrc
sudo cp configs/.zshrc ~/.zshrc