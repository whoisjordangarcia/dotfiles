#!/bin/bash
#===============================================================================
# system-funcs.sh - System monitoring & management functions
#===============================================================================

#-------------------------------------------------------------------------------
# System Info
#-------------------------------------------------------------------------------

sysinfo() {
    echo "=== System Info ==="
    [[ -f /etc/os-release ]] && grep -E "PRETTY_NAME|VERSION" /etc/os-release
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime -p)"
    echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
    echo ""
    echo "=== Resources ==="
    echo "CPU: $(nproc) cores"
    free -h | awk '/^Mem:/ {print "RAM: " $3 "/" $2}'
    df -h / | awk 'NR==2 {print "Disk: " $3 " used / " $2 " (" $5 ")"}'
}

#-------------------------------------------------------------------------------
# Process Management
#-------------------------------------------------------------------------------

pkillx() {
    if [[ -z "$1" ]]; then
        echo "Usage: pkillx <process-name>"
        return 1
    fi
    pkill -9 -f "$1"
    echo "Killed processes matching: $1"
}

pstop() {
    [[ -z "$1" ]] && echo "Usage: pstop <pid>" && return 1
    kill -STOP "$1"
    echo "Stopped PID $1"
}

pcont() {
    [[ -z "$1" ]] && echo "Usage: pcont <pid>" && return 1
    kill -CONT "$1"
    echo "Resumed PID $1"
}

#-------------------------------------------------------------------------------
# Network
#-------------------------------------------------------------------------------

myipinfo() {
    echo "Local: $(ip addr show | grep 'inet ' | awk '{print $2}' | head -1)"
    echo "Public: $(curl -s ifconfig.me)"
}

portcheck() {
    [[ -z "$1" ]] && echo "Usage: portcheck <port>" && return 1
    netstat -tulpn 2>/dev/null | grep ":$1 " || ss -tulpn | grep ":$1 "
}

#-------------------------------------------------------------------------------
# Quick Services
#-------------------------------------------------------------------------------

servrestart() {
    [[ -z "$1" ]] && echo "Usage: servrestart <service-name>" && return 1
    sudo systemctl restart "$1"
    sudo systemctl status "$1" --no-pager
}

servstatus() {
    [[ -z "$1" ]] && echo "Usage: servstatus <service-name>" && return 1
    sudo systemctl status "$1" --no-pager
}

#-------------------------------------------------------------------------------
# User Management
#-------------------------------------------------------------------------------

adduser() {
    [[ -z "$1" ]] && echo "Usage: adduser <username>" && return 1
    sudo adduser "$1"
    sudo usermod -aG sudo "$1"
    echo "User $1 added to sudo group"
}

#-------------------------------------------------------------------------------
# Disk Usage
#-------------------------------------------------------------------------------

largest_files() {
    local dir="${1:-.}"
    local count="${2:-10}"
    find "$dir" -type f -exec du -h {} + 2>/dev/null | sort -rh | head -n "$count"
}

largest_dirs() {
    local dir="${1:-.}"
    local count="${2:-10}"
    du -h "$dir" 2>/dev/null | sort -rh | head -n "$count"
}

#===============================================================================
# PROXMOX FUNCTIONS
#===============================================================================

if [[ -f /etc/pve/proxmox-release ]]; then

    # VM Console
    vmconsole() {
        [[ -z "$1" ]] && echo "Usage: vmconsole <vmid>" && return 1
        qm terminal "$1"
    }

    # Container Console
    ctconsole() {
        [[ -z "$1" ]] && echo "Usage: ctconsole <ctid>" && return 1
        pct enter "$1"
    }

    # Quick clone
    vmclone() {
        [[ -z "$1" ]] || [[ -z "$2" ]] && echo "Usage: vmclone <source-vmid> <new-vmid>" && return 1
        qm clone "$1" "$2" --name "clone-$2"
    }

    # VM backup
    vmbackup() {
        [[ -z "$1" ]] && echo "Usage: vmbackup <vmid>" && return 1
        vzdump "$1" --mode suspend --compress zstd
    }

    # List all VMs & CTs with status
    vmstatus() {
        echo "=== VMs ==="
        qm list
        echo ""
        echo "=== Containers ==="
        pct list
    }

    # Storage usage
    pvestorage() {
        pvesm status | grep -E "^local|^shared"
    }

fi
