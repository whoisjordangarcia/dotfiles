if [[ -n "$SSH_CONNECTION" ]]; then
    export TERM=xterm-256color
fi

load_special_config() {
    if [[ -f "$HOME/.zshrc-work-mode" ]]; then
        echo "Work mode detected - loading .zshrc.work"
        source ~/.zshrc-modules/.zshrc.work
        return 0
    elif [[ -f "$HOME/.zshrc-arch-mode" ]]; then
        #echo "Arch mode detected - loading .zshrc.arch"
        return 0
    fi
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

# secrets
source ~/.zshrc-modules/.zshrc.sec
source ~/.zshrc-sec

if ! load_special_config; then
    echo 'No special mode detected. Loading .zshrc.personal'
    source ~/.zshrc-modules/.zshrc.personal
fi



