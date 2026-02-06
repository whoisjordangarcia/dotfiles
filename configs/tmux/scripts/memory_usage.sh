#!/bin/bash

# Memory usage script for tmux statusline
# Uses Nerd Font icons via UTF-8 byte sequences (bash 3.2 compatible)

ICON_MEM=$(printf '\xf3\xb0\x8d\x9b')  # U+F035B nf-md-memory

get_memory_usage() {
	case "$(uname -s)" in
	Darwin)
		total_mem=$(sysctl -n hw.memsize 2>/dev/null)
		if [ -n "$total_mem" ]; then
			total_gb=$(echo "$total_mem" | awk '{printf "%.0f", $1/1073741824}')
			page_size=$(sysctl -n hw.pagesize 2>/dev/null)
			vm_stat_output=$(vm_stat 2>/dev/null)
			pages_active=$(echo "$vm_stat_output" | awk '/Pages active/ {gsub(/\./,"",$3); print $3}')
			pages_wired=$(echo "$vm_stat_output" | awk '/Pages wired/ {gsub(/\./,"",$4); print $4}')
			if [ -n "$pages_active" ] && [ -n "$pages_wired" ]; then
				used_bytes=$(( (pages_active + pages_wired) * page_size ))
				used_gb=$(echo "$used_bytes $total_mem" | awk '{printf "%.1f", $1/1073741824}')
				echo "${ICON_MEM} ${used_gb}/${total_gb}G"
			else
				echo ""
			fi
		else
			echo ""
		fi
		;;
	Linux)
		if [ -r /proc/meminfo ]; then
			total_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null)
			avail_kb=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null)

			if [ -n "$total_kb" ] && [ -n "$avail_kb" ]; then
				used_kb=$((total_kb - avail_kb))
				used_gb=$(echo "$used_kb" | awk '{printf "%.1f", $1/1048576}')
				total_gb=$(echo "$total_kb" | awk '{printf "%.0f", $1/1048576}')
				echo "${ICON_MEM} ${used_gb}/${total_gb}G"
			else
				echo ""
			fi
		else
			echo ""
		fi
		;;
	*)
		echo ""
		;;
	esac
}

get_memory_usage
