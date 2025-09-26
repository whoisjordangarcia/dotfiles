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
source ~/.zshrc-modules/.zshrc.starship
source ~/.zshrc-modules/.zshrc.ohmyzsh
source ~/.zshrc-modules/.zshrc.envvars
source ~/.zshrc-modules/.zshrc.aliases
source ~/.zshrc-modules/.zshrc.functions
source ~/.zshrc-modules/.zshrc.init
source ~/.zshrc-modules/.zshrc.paths
source ~/.zshrc-modules/.zshrc.appearance

export PATH="$HOME/.pyenv/shims:$PATH"

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



export PYTHONHTTPSVERIFY=0
export CURL_CA_BUNDLE=""
export REQUESTS_CA_BUNDLE=""
