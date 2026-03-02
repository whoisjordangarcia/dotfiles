#!/bin/bash
# System functions

sysinfo() {
    echo "=== System Info ==="
    [[ -f /etc/os-release ]] && grep -E "PRETTY_NAME" /etc/os-release
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime -p)"
    echo ""
    echo "=== Resources ==="
    echo "CPU: $(nproc) cores"
    free -h | awk '/^Mem:/ {print "RAM: " $3 "/" $2}'
    df -h / | awk 'NR==2 {print "Disk: " $3 " used / " $2 " (" $5 ")"}'
}

pkillx() {
    [[ -z "$1" ]] && echo "Usage: pkillx <process>" && return 1
    pkill -9 -f "$1"
}

myipinfo() {
    echo "Local: $(hostname -I 2>/dev/null)"
    echo "Public: $(curl -s ifconfig.me)"
}

portcheck() {
    [[ -z "$1" ]] && echo "Usage: portcheck <port>" && return 1
    netstat -tulpn 2>/dev/null | grep ":$1 " || ss -tulpn | grep ":$1 "
}

# Proxmox functions
[[ -f /etc/pve/proxmox-release ]] && vmconsole() {
    [[ -z "$1" ]] && echo "Usage: vmconsole <vmid>" && return 1
    qm terminal "$1"
}

[[ -f /etc/pve/proxmox-release ]] && ctconsole() {
    [[ -z "$1" ]] && echo "Usage: ctconsole <ctid>" && return 1
    pct enter "$1"
}

[[ -f /etc/pve/proxmox-release ]] && vmbackup() {
    [[ -z "$1" ]] && echo "Usage: vmbackup <vmid>" && return 1
    vzdump "$1" --mode suspend --compress zstd
}