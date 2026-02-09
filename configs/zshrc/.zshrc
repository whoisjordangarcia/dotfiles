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
source ~/.zshrc-modules/.zshrc.history
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

# secrets
[[ -f ~/.zshrc-modules/.zshrc.sec ]] && source ~/.zshrc-modules/.zshrc.sec
[[ -f ~/.zshrc-sec ]] && source ~/.zshrc-sec

# Work mode: touch ~/.zshrc-work-mode to enable
if [[ -f ~/.zshrc-work-mode ]]; then
    [[ -f ~/.zshrc-modules/.zshrc.work ]] && source ~/.zshrc-modules/.zshrc.work
else
    [[ -f ~/.zshrc-modules/.zshrc.personal ]] && source ~/.zshrc-modules/.zshrc.personal
fi

export GPG_TTY=$(tty)
export PATH="$HOME/.local/bin:$PATH"

alias claude-mem='bun "/Users/nest/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'

#export NEST_WT_EDITOR="zed"
export NEST_REPO_ROOT="$HOME/projects/nest"
