#!/bin/bash
#===============================================================================
# .bash_profile - Login Shell Configuration
# Executed for login shells (SSH, console login)
#===============================================================================

# Source .bashrc if it exists (most configs live there)
if [[ -f "$HOME/.bashrc" ]]; then
    source "$HOME/.bashrc"
fi

#------------------------------------------------------------------------------
# LOGIN-SPECIFIC CONFIGURATION
#------------------------------------------------------------------------------

# Set up SSH agent (if not already running)
if [[ -z "$SSH_AUTH_SOCK" ]] && command -v ssh-agent &>/dev/null; then
    eval "$(ssh-agent -s)" &>/dev/null
fi

# Add SSH keys
if [[ -f "$HOME/.ssh/id_rsa" ]]; then
    ssh-add "$HOME/.ssh/id_rsa" 2>/dev/null || true
fi

if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
    ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null || true
fi

#------------------------------------------------------------------------------
# PATH ADDITIONS (login-time only)
#------------------------------------------------------------------------------

# Go
if [[ -d /usr/local/go/bin ]]; then
    export PATH="$PATH:/usr/local/go/bin"
fi
if [[ -d "$HOME/go/bin" ]]; then
    export PATH="$PATH:$HOME/go/bin"
fi

# Rust/Cargo
if [[ -d "$HOME/.cargo/bin" ]]; then
    export PATH="$PATH:$HOME/.cargo/bin"
fi

# Node/PNPM
if [[ -d "$HOME/.local/share/pnpm" ]]; then
    export PATH="$PATH:$HOME/.local/share/pnpm"
fi

# Python (user site)
if command -v python3 &>/dev/null; then
    PYTHON_USER_SITE="$(python3 -m site --user-base 2>/dev/null)/bin"
    if [[ -d "$PYTHON_USER_SITE" ]]; then
        export PATH="$PATH:$PYTHON_USER_SITE"
    fi
fi

#------------------------------------------------------------------------------
# ENVIRONMENT VARIABLES
#------------------------------------------------------------------------------

# Locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# XDG directories
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

# GPG
export GPG_TTY=$(tty)

#------------------------------------------------------------------------------
# SERVER-SPECIFIC LOGIN ACTIONS
#------------------------------------------------------------------------------

# Check for Proxmox
if [[ -f /etc/pve/proxmox-release ]]; then
    # Ensure pvesh is accessible
    export PATH="$PATH:/usr/share/pve-manager/bin"
fi

# Check for critical issues (only on login)
if [[ $EUID -eq 0 ]]; then
    # Check disk space
    DISK_USAGE=$(df / 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%')
    if [[ -n "$DISK_USAGE" ]] && [[ "$DISK_USAGE" -gt 90 ]]; then
        echo ""
        echo "⚠️  WARNING: Root filesystem is ${DISK_USAGE}% full!"
        echo "   Run 'df -h' for details."
        echo ""
    fi
    
    # Check for failed systemd services
    if command -v systemctl &>/dev/null; then
        FAILED=$(systemctl --failed --quiet 2>/dev/null | grep -c "failed" || echo "0")
        if [[ "$FAILED" -gt 0 ]]; then
            echo ""
            echo "⚠️  WARNING: $FAILED systemd service(s) failed!"
            echo "   Run 'systemctl --failed' for details."
            echo ""
        fi
    fi
    
    # Check for unattended upgrades
    if [[ -f /var/run/reboot-required ]]; then
        echo ""
        echo "🔄 REBOOT REQUIRED: System updates need a restart."
        echo ""
    fi
fi
