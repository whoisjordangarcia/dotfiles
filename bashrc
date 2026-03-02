#!/bin/bash
#===============================================================================
# .bashrc - Main Bash Configuration
# Production-ready configuration for servers and Proxmox environments
# Source: https://github.com/yourusername/dotfiles
#===============================================================================

#------------------------------------------------------------------------------
# INITIAL SETUP & GUARDS
#------------------------------------------------------------------------------

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Source global definitions if they exist
if [[ -f /etc/bashrc ]]; then
    source /etc/bashrc
elif [[ -f /etc/bash.bashrc ]]; then
    source /etc/bash.bashrc
fi

#------------------------------------------------------------------------------
# ENVIRONMENT DETECTION
#------------------------------------------------------------------------------

# Detect environment type
export IS_PROXMOX=false
export IS_DOCKER=false
export IS_SERVER=false
export HAS_SYSTEMD=false

# Check for Proxmox
if [[ -f /etc/pve/proxmox-release ]] || [[ -d /etc/pve ]]; then
    IS_PROXMOX=true
fi

# Check for Docker
if [[ -f /.dockerenv ]] || grep -qE 'docker|containerd' /proc/1/cgroup 2>/dev/null; then
    IS_DOCKER=true
fi

# Check for systemd
if command -v systemctl &>/dev/null; then
    HAS_SYSTEMD=true
fi

# Server detection (not a desktop/laptop)
if [[ ! -d /home ]] && [[ $EUID -eq 0 ]] || [[ -d /var/www ]] || [[ -d /etc/nginx ]]; then
    IS_SERVER=true
fi

#------------------------------------------------------------------------------
# HISTORY CONFIGURATION
#------------------------------------------------------------------------------

# Unlimited history
export HISTSIZE=100000
export HISTFILESIZE=200000

# Don't put duplicate lines or lines starting with space in history
export HISTCONTROL=ignoreboth:erasedups

# Append to history, don't overwrite
shopt -s histappend

# Save multi-line commands as single entry
shopt -s cmdhist

# History timestamp format
export HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S  "

# History file location
export HISTFILE="$HOME/.bash_history"

# Save history after every command
export PROMPT_COMMAND="history -a; history -c; history -r; \${PROMPT_COMMAND}"

# Commands to ignore in history
export HISTIGNORE="&:ls:ll:la:cd:pwd:bg:fg:history:clear:exit:reboot:poweroff"

#------------------------------------------------------------------------------
# CUSTOM LOGGING (for audit/security)
#------------------------------------------------------------------------------

export BASH_LOG_DIR="$HOME/.logs/bash"
export BASH_HISTORY_LOG="$BASH_LOG_DIR/history.log"
export BASH_COMMANDS_LOG="$BASH_LOG_DIR/commands.log"

# Ensure log directory exists
mkdir -p "$BASH_LOG_DIR"

# Log all commands (with timestamp, user, pwd)
log_command() {
    local cmd="$1"
    [[ -z "$cmd" ]] && return
    [[ "$cmd" =~ ^(log_command|source|\. ) ]] && return
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') $(hostname) $(whoami) [\$$] [${PWD}] $cmd" >> "$BASH_COMMANDS_LOG"
}

# Enhanced PROMPT_COMMAND with logging
setup_logging() {
    local last_cmd=$(history 1 | sed 's/^ *[0-9]* *//')
    log_command "$last_cmd"
}

export PROMPT_COMMAND="setup_logging; history -a; history -c; history -r"

#------------------------------------------------------------------------------
# SHELL OPTIONS
#------------------------------------------------------------------------------

# Check window size after each command
shopt -s checkwinsize

# Enable pattern expansion
shopt -s extglob

# Enable recursive globbing
shopt -s globstar 2>/dev/null

# Don't autocomplete when pasting URLs
bind 'set enable-bracketed-paste on' 2>/dev/null

# Correct minor spelling errors in cd
shopt -s cdspell 2>/dev/null

#------------------------------------------------------------------------------
# PATH CONFIGURATION
#------------------------------------------------------------------------------

# User local bin
if [[ -d "$HOME/.local/bin" ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# User bin
if [[ -d "$HOME/bin" ]]; then
    export PATH="$HOME/bin:$PATH"
fi

# Snap packages
if [[ -d /snap/bin ]]; then
    export PATH="$PATH:/snap/bin"
fi

# Proxmox specific paths
if [[ "$IS_PROXMOX" == true ]]; then
    # pvesh and other Proxmox tools are in standard paths
    export PATH="$PATH:/usr/share/pve-manager/bin"
fi

#------------------------------------------------------------------------------
# EDITOR CONFIGURATION
#------------------------------------------------------------------------------

# Default editor priority: nvim > vim > nano
if command -v nvim &>/dev/null; then
    export EDITOR='nvim'
    export VISUAL='nvim'
    alias vim='nvim'
elif command -v vim &>/dev/null; then
    export EDITOR='vim'
    export VISUAL='vim'
else
    export EDITOR='nano'
    export VISUAL='nano'
fi

# Set default pager
if command -v less &>/dev/null; then
    export PAGER='less'
    export LESS='-R -i -g -c -W -M -X -F'
fi

#------------------------------------------------------------------------------
# LOCALE & MISC
#------------------------------------------------------------------------------

# Prevent less from clearing screen
export LESS='-R -M -X -i --mouse'

# Colors for man pages
export MANPAGER="less -R --use-color -Dd+r -Du+b"

# Disable Ctrl+S (XOFF)
stty -ixon 2>/dev/null

#------------------------------------------------------------------------------
# LOAD MODULES
#------------------------------------------------------------------------------

# Load aliases
if [[ -f ~/.bash_aliases ]]; then
    source ~/.bash_aliases
fi

# Load functions from .config
if [[ -d ~/.config/bash/functions ]]; then
    for func in ~/.config/bash/functions/*.sh; do
        [[ -r "$func" ]] && source "$func"
    done
fi

#------------------------------------------------------------------------------
# CUSTOM FUNCTIONS (inline, for quick access)
#------------------------------------------------------------------------------

# Quick edit bashrc
eb() {
    $EDITOR ~/.bashrc
}

# Reload bashrc
rb() {
    source ~/.bashrc
    echo "✓ .bashrc reloaded"
}

# Show system info on login
show_motd() {
    # Only show in interactive shells on SSH or first terminal
    if [[ -n "$SSH_CONNECTION" ]] || [[ "$SHLVL" -eq 1 ]]; then
        echo ""
        # System info
        if command -v hostnamectl &>/dev/null; then
            hostnamectl | grep -E "Static hostname|Operating System|Kernel" 2>/dev/null || true
        fi
        
        # Load
        uptime | awk -F'load average:' '{print "Load Average:" $2}' 2>/dev/null || true
        
        # Disk usage (brief)
        df -h / 2>/dev/null | tail -1 | awk '{print "Disk Usage: " $5 " of " $2}'
        
        # Memory
        free -h 2>/dev/null | awk '/^Mem:/ {print "Memory: " $3 " / " $2 " used"}'
        
        # Proxmox specific
        if [[ "$IS_PROXMOX" == true ]] && command -v pvesh &>/dev/null; then
            echo ""
            echo "Proxmox VE: $(pveversion 2>/dev/null | head -1)"
            echo "Running VMs/CTs: $(qm list 2>/dev/null | grep -c running)/$(pct list 2>/dev/null | grep -c running)"
        fi
        
        echo ""
    fi
}

# Call MOTD on login
show_motd

#------------------------------------------------------------------------------
# PROMPT CONFIGURATION (PS1)
#------------------------------------------------------------------------------

# Colors
if [[ -x /usr/bin/tput ]] && tput setaf 1 &>/dev/null; then
    RESET='\[\e[0m\]'
    RED='\[\e[31m\]'
    GREEN='\[\e[32m\]'
    YELLOW='\[\e[33m\]'
    BLUE='\[\e[34m\]'
    MAGENTA='\[\e[35m\]'
    CYAN='\[\e[36m\]'
    WHITE='\[\e[37m\]'
    BOLD='\[\e[1m\]'
fi

# Git branch in prompt (if git is installed)
parse_git_branch() {
    git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}

# Docker container indicator
docker_indicator() {
    if [[ "$IS_DOCKER" == true ]]; then
        echo "${YELLOW}[docker]${RESET} "
    fi
}

# Proxmox indicator
proxmox_indicator() {
    if [[ "$IS_PROXMOX" == true ]]; then
        echo "${MAGENTA}[pve]${RESET} "
    fi
}

# Exit status indicator
exit_status() {
    local status=$?
    if [[ $status -ne 0 ]]; then
        echo "${RED}[${status}]${RESET} "
    fi
}

# Build prompt based on user
if [[ $EUID -eq 0 ]]; then
    # Root user prompt - red to warn
    PS1="${debian_chroot:+($debian_chroot)}${BOLD}${RED}\u@\h${RESET}:${BLUE}\w${RESET}\n\\$ "
else
    # Regular user - informative and colorful
    PS1="${debian_chroot:+($debian_chroot)}$(exit_status)$(docker_indicator)$(proxmox_indicator)${GREEN}\u@\h${RESET}:${BLUE}\w${RESET} ${YELLOW}\$(parse_git_branch)${RESET}\\$ "
fi

#------------------------------------------------------------------------------
# SECURITY & SAFETY
#------------------------------------------------------------------------------

# Prevent accidental rm -rf /
set --delete 2>/dev/null || true
alias rm='rm -I --preserve-root'

# Safer mv/cp
alias mv='mv -i'
alias cp='cp -i'
alias ln='ln -i'

#------------------------------------------------------------------------------
# PLATFORM-SPECIFIC FINALIZATIONS
#------------------------------------------------------------------------------

# macOS-specific
if [[ "$OSTYPE" == "darwin"* ]]; then
    export CLICOLOR=1
    export LSCOLORS=ExFxBxDxCxegedabagacad
    alias ls='ls -GF'
fi

#------------------------------------------------------------------------------
# FINAL MESSAGES
#------------------------------------------------------------------------------

# Mark this as loaded
export DOTFILES_BASHRC_LOADED=true
