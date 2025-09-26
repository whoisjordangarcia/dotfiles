#!/bin/bash

# IP address detection script for tmux statusline
# Supports macOS and Linux platforms

get_ip_address() {
    case "$(uname -s)" in
        Darwin)
            # macOS - check GlobalProtect VPN interfaces first
            # GlobalProtect typically uses utun interfaces or gpd interfaces
            for interface in $(ifconfig -l | tr ' ' '\n' | grep -E '^(utun|gpd|ppp)'); do
                # Use ifconfig instead of ipconfig for point-to-point interfaces
                ip=$(ifconfig "$interface" 2>/dev/null | awk '/inet / && !/127\.0\.0\.1/ { print $2 }')
                if [ -n "$ip" ] && [ "$ip" != "127.0.0.1" ]; then
                    # Check if this looks like a VPN IP (common VPN ranges)
                    case "$ip" in
                        10.*|172.1[6-9].*|172.2[0-9].*|172.3[0-1].*|192.168.*|100.*)
                            echo "🔒 $ip"
                            return 0
                            ;;
                    esac
                fi
            done
            
            # If no VPN found, check regular interfaces
            for interface in en0 en1 en2 en3; do
                ip=$(ipconfig getifaddr "$interface" 2>/dev/null)
                if [ -n "$ip" ] && [ "$ip" != "127.0.0.1" ]; then
                    echo "$ip"
                    return 0
                fi
            done
            echo "N/A"
            ;;
        Linux)
            # Linux - multiple approaches for different distributions

            # Method 1: Try ip command (most modern Linux distributions)
            if command -v ip >/dev/null 2>&1; then
                ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{
                    for(i=1;i<=NF;i++) {
                        if($i=="src") {
                            print $(i+1)
                            exit
                        }
                    }
                }')
                if [ -n "$ip" ] && [ "$ip" != "127.0.0.1" ]; then
                    echo "$ip"
                    return 0
                fi

                # Fallback: get first non-loopback IP
                ip=$(ip -4 -o addr show scope global up 2>/dev/null | awk '{
                    split($4,a,"/")
                    if(a[1] != "127.0.0.1") {
                        print a[1]
                        exit
                    }
                }')
                if [ -n "$ip" ]; then
                    echo "$ip"
                    return 0
                fi
            fi

            # Method 2: Try hostname command
            if command -v hostname >/dev/null 2>&1; then
                ip=$(hostname -I 2>/dev/null | awk '{print $1}')
                if [ -n "$ip" ] && [ "$ip" != "127.0.0.1" ]; then
                    echo "$ip"
                    return 0
                fi
            fi

            # Method 3: Parse /proc/net/route and get IP from interface
            if [ -r /proc/net/route ]; then
                interface=$(awk '/^[^I]/ && $2=="00000000" {print $1; exit}' /proc/net/route 2>/dev/null)
                if [ -n "$interface" ] && command -v ip >/dev/null 2>&1; then
                    ip=$(ip -4 addr show "$interface" 2>/dev/null | awk '/inet / && !/127\.0\.0\.1/ {
                        gsub(/\/.*/, "", $2)
                        print $2
                        exit
                    }')
                    if [ -n "$ip" ]; then
                        echo "$ip"
                        return 0
                    fi
                fi
            fi

            echo "N/A"
            ;;
        *)
            echo "N/A"
            ;;
    esac
}

get_ip_address