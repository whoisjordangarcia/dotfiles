#!/bin/bash

# Set default log level if not specified
LOG_LEVEL=${LOG_LEVEL:-info}

RED="\033[0;31m"
GREEN="\033[00;32m"
YELLOW="\033[0;33m"
BLUE="\033[00;34m"
RESET="\033[0m"

# Log level hierarchy: debug=0, info=1, warn=2, error=3
_get_log_level_num() {
    case "${1:-info}" in
        debug) echo 0 ;;
        info) echo 1 ;;
        warn) echo 2 ;;
        error) echo 3 ;;
        *) echo 1 ;; # default to info
    esac
}

_should_log() {
    local message_level=$1
    local current_level_num=$(_get_log_level_num "$LOG_LEVEL")
    local message_level_num=$(_get_log_level_num "$message_level")
    [ "$message_level_num" -ge "$current_level_num" ]
}

debug() {
    if _should_log "debug"; then
        printf "\r${BLUE}DEBUG${RESET} $1\n" >&2
    fi
}

info() {
    if _should_log "info"; then
        printf "\r$1\n" >&2
    fi
}

# Section header - for major installation phases
section() {
    if _should_log "info"; then
        printf "\r${BLUE}▶${RESET} ${BLUE}$1${RESET}\n" >&2
    fi
}

# Step within a section - for individual components
step() {
    if _should_log "info"; then
        printf "\r    • $1\n" >&2
    fi
}

# Status update - for environment detection, etc
status() {
    if _should_log "info"; then
        printf "\r${YELLOW}INFO${RESET} $1\n" >&2
    fi
}

# Clean prompt - for interactive setup
prompt() {
    printf "\r${BLUE}▶${RESET} $1" >&2
}

# Clean header - for major sections
header() {
    if _should_log "info"; then
        printf "\r\n${BLUE}━━━ $1 ━━━${RESET}\n" >&2
    fi
}

# Prompts user input
user() {
    printf "\r${YELLOW}??${RESET} $1\n" >&2
}

# Indicates success
success() {
    printf "\r\033[2K${GREEN}OK${RESET} $1\n" >&2
}

# Indicates failure and exits
fail() {
    local exit_code=${2:-1} # Default exit code is 1 if not provided
    printf "\r\033[2K${RED}FAIL${RESET} $1\n" >&2
    echo ''
    exit $exit_code
}

