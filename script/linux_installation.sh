info() {
	printf "\r  [ \033[00;34m..\033[0m ] $1\n"
}

user() {
	printf "\r  [ \033[0;33m??\033[0m ] $1\n"
}

success() {
	printf "\r\033[2K  [ \033[00;32mOK\033[0m ] $1\n"
}

fail() {
	printf "\r\033[2K  [\033[0;31mFAIL\033[0m] $1\n"
	echo ''
	exit
}

# Fail on any command.
set -eux pipefail

# Install ZSH
info "installing zsh..."
apt install zsh

# Install oh-my-zsh
info "installing oh-my-zsh..."
info "make sure to add correct credentials"
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install powerlevel 10k
info "installing powerlevel10k..."
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# Install nvm
info "installing nvm..."
curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
source ~/.zshrc

# Default zsh
info "Defaulting zsh..."
chsh -s $(which zsh)

# Install zsh-autosuggestions
info "Defaulting Installing zsh-autosuggestions..."
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# Install zsh-syntax-highlighting
info "Defaulting Installing zsh-syntax-highlighting..."
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Install fzf plugin
info "Defaulting Installing fzf..."
git clone --depth 1 https://github.com/unixorn/fzf-zsh-plugin.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-zsh-plugin

# Install neovim
info "installing neovim...."
apt-get install software-properties-common
add-apt-repository ppa:neovim-ppa/unstable
apt-get update
apt-get install neovim

# Install ripgrep
apt install ripgrep

# Override the config for .zshrc
info "Defaulting copy .zshrc file over..."
sudo cp configs/.zshrc ~/.zshrc
