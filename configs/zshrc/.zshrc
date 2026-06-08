if [[ -n "$SSH_CONNECTION" ]]; then export TERM=xterm-256color; fi

# Keep $PATH entries unique so re-sourcing this file (e.g. `reload`) is
# idempotent — without this, every prepend in .zshrc.{envvars,paths} stacks
# another duplicate copy onto PATH.
typeset -U path PATH

# defaults
source ~/.zshrc-modules/.zshrc.history
source ~/.zshrc-modules/.zshrc.init
source ~/.zshrc-modules/.zshrc.plugins
source ~/.zshrc-modules/.zshrc.envvars
source ~/.zshrc-modules/.zshrc.aliases
source ~/.zshrc-modules/.zshrc.functions
source ~/.zshrc-modules/.zshrc.paths
source ~/.zshrc-modules/.zshrc.appearance
source ~/.zshrc-modules/.zshrc.vim-mode

#export PATH="$HOME/.pyenv/shims:$PATH"

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

export GPG_TTY=$TTY
export PATH="$HOME/.local/bin:$PATH"

# bun completions (BUN_INSTALL is exported in .zshrc.envvars; defaults to ~/.bun)
[ -s "${BUN_INSTALL:-$HOME/.bun}/_bun" ] && source "${BUN_INSTALL:-$HOME/.bun}/_bun"

# Resolve the highest installed claude-mem plugin version instead of hardcoding
# one (the pinned path breaks on every plugin update).
_claude_mem_base="$HOME/.claude/plugins/cache/thedotmack/claude-mem"
_claude_mem_latest=("$_claude_mem_base"/*/scripts/worker-service.cjs(Nn))
(( ${#_claude_mem_latest} )) && alias claude-mem="bun ${_claude_mem_latest[-1]}"
unset _claude_mem_base _claude_mem_latest
