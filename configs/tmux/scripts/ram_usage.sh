#!/bin/bash

# RAM usage script for tmux statusline
# Supports macOS and Linux platforms

get_ram_usage() {
    case "$(uname -s)" in
        Darwin)
            # macOS - use memory_pressure command
            if command -v memory_pressure >/dev/null 2>&1; then
                memory_pressure -Q 2>/dev/null | awk -F': ' '
                /System-wide memory free percentage/ {
                    gsub(/%/,"",$2);
                    printf "%d%%", 100-$2
                }'
            else
                echo "N/A"
            fi
            ;;
        Linux)
            # Linux - use /proc/meminfo or free command
            if [ -r /proc/meminfo ]; then
                awk '/^MemTotal:/ {total=$2} /^MemAvailable:/ {avail=$2} END {
                    if (avail > 0 && total > 0) {
                        used = total - avail
                        printf "%.0f%%", (used/total)*100
                    } else {
                        print "N/A"
                    }
                }' /proc/meminfo
            elif command -v free >/dev/null 2>&1; then
                free -m | awk '/^Mem:/ {
                    if ($2 > 0) {
                        printf "%.0f%%", ($3/$2)*100
                    } else {
                        print "N/A"
                    }
                }'
            else
                echo "N/A"
            fi
            ;;
        *)
            echo "N/A"
            ;;
    esac
}

get_ram_usage