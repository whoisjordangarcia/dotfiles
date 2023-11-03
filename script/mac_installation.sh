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

# Install oh-my-zsh
info "installing oh-my-zsh..."
info "make sure to add correct credentials"
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install zsh-autosuggestions
info "Defaulting Installing zsh-autosuggestions..."
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# Install zsh-syntax-highlighting
info "Defaulting Installing zsh-syntax-highlighting..."
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Install fzf plugin
info "Defaulting Installing fzf..."
git clone --depth 1 https://github.com/unixorn/fzf-zsh-plugin.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-zsh-plugin

# Install lolcat
brew install lolcat

# Install figlet
brewq install figlet

# Install fzf
brew install fzf

# Override the config for .zshrc
info "Defaulting copy .zshrc file over..."
sudo cp configs/.zshrc ~/.zshrc