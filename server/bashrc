# Server & Proxmox .bashrc

[[ $- != *i* ]] && return
[[ -f /etc/bash.bashrc ]] && source /etc/bash.bashrc

# Env detection
export IS_PROXMOX=false
export IS_DOCKER=false
export HAS_SYSTEMD=false
[[ -f /etc/pve/proxmox-release ]] && IS_PROXMOX=true
[[ -f /.dockerenv ]] && IS_DOCKER=true
command -v systemctl &>/dev/null && HAS_SYSTEMD=true

# History
export HISTSIZE=100000
export HISTFILESIZE=200000
export HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
export HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S  "
export HISTIGNORE="&:ls:ll:la:cd:pwd:bg:fg:history:exit:reboot:poweroff"

# Path
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"
[[ -d "$HOME/bin" ]] && export PATH="$HOME/bin:$PATH"
[[ -d /snap/bin ]] && export PATH="$PATH:/snap/bin"
[[ "$IS_PROXMOX" == true ]] && export PATH="$PATH:/usr/share/pve-manager/bin"

# Editor
if command -v nvim &>/dev/null; then
    export EDITOR='nvim'; alias vim='nvim'
elif command -v vim &>/dev/null; then
    export EDITOR='vim'
else
    export EDITOR='nano'
fi
export PAGER='less'
export LESS='-R -i -g -c -W -M -X -F'

# Shell options
shopt -s checkwinsize extglob globstar cdspell 2>/dev/null
stty -ixon 2>/dev/null

# Load aliases & functions
[[ -f ~/.bash_aliases ]] && source ~/.bash_aliases
[[ -d ~/.config/bash/functions ]] && for f in ~/.config/bash/functions/*.sh; do [[ -r "$f" ]] && source "$f"; done

# Quick functions
eb() { $EDITOR ~/.bashrc; }
rb() { source ~/.bashrc && echo "✓ Reloaded"; }

# MOTD
show_info() {
    [[ -n "$SSH_CONNECTION" ]] || [[ "$SHLVL" -eq 1 ]] || return
    echo ""; uptime | awk -F'load average:' '{print "Load:" $2}'
    df -h / 2>/dev/null | tail -1 | awk '{print "Disk:" $5 " used of " $2}'
    free -h 2>/dev/null | awk '/^Mem:/ {print "RAM:" $3 "/" $2}'
    [[ "$IS_PROXMOX" == true ]] && echo "Proxmox: $(pveversion 2>/dev/null | head -1)"
    echo ""
}
show_info

# Prompt
RESET='\e[0m' RED='\e[31m' GREEN='\e[32m' YELLOW='\e[33m' BLUE='\e[34m' MAGENTA='\e[35m'
parse_git_branch() { git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'; }
if [[ $EUID -eq 0 ]]; then
    PS1="${RED}\u@\h${RESET}:${BLUE}\w${RESET}\n\$ "
else
    PS1="${GREEN}\u@\h${RESET}:${BLUE}\w${RESET} ${YELLOW}\$(parse_git_branch)${RESET}\$ "
fi

# Safety
alias rm='rm -I --preserve-root'
alias mv='mv -i'
alias cp='cp -i'

export DOTFILES_BASHRC_LOADED=true