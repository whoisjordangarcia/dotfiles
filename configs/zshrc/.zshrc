if [[ -n "$SSH_CONNECTION" ]]; then export TERM=xterm-256color; fi

source_files() {
    for config_file in "$@"; do
        if [[ -f "$config_file" ]]; then
            echo "Loading $config_file"
            source "$config_file"
            return 0
        fi
    done
    return 1
}

# defaults
source ~/.zshrc-modules/.zshrc.init
source ~/.zshrc-modules/.zshrc.ohmyzsh
source ~/.zshrc-modules/.zshrc.envvars
source ~/.zshrc-modules/.zshrc.aliases
source ~/.zshrc-modules/.zshrc.functions
source ~/.zshrc-modules/.zshrc.paths
source ~/.zshrc-modules/.zshrc.appearance
source ~/.zshrc-modules/.zshrc.vim-mode


export PATH="$HOME/.pyenv/shims:$PATH"

# Custom man pages for dotfiles
export MANPATH="$HOME/dev/dotfiles/configs/man:$MANPATH"

# special config files to try loading
special_config_files=(
    ~/.zshrc-work-mode
)

# secrets
[[ -f ~/.zshrc-modules/.zshrc.sec ]] && source ~/.zshrc-modules/.zshrc.sec
[[ -f ~/.zshrc-sec ]] && source ~/.zshrc-sec

if ! source_files "${special_config_files[@]}"; then
  [[ -f ~/.zshrc-modules/.zshrc.personal ]] && source ~/.zshrc-modules/.zshrc.personal
fi

export GPG_TTY=$(tty)



# Automatically use Node version from .nvmrc
#autoload -U add-zsh-hook
# load-nvmrc() {
#   local nvmrc_path="$(nvm_find_nvmrc)"
#   if [ -n "$nvmrc_path" ]; then
#     local nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")
#     if [ "$nvmrc_node_version" = "N/A" ]; then
#       nvm install
#     elif [ "$nvmrc_node_version" != "$(nvm version)" ]; then
#       nvm use
#     fi
#   elif [ -n "$(PWD=$OLDPWD nvm_find_nvmrc)" ] && [ "$(nvm version)" != "$(nvm version default)" ]; then
#     echo "Reverting to nvm default version"
#     nvm use default
#   fi
# }
# add-zsh-hook chpwd load-nvmrc
# load-nvmrc
export PATH="$HOME/.local/bin:$PATH"
