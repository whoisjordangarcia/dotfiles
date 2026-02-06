#!/bin/bash

# CPU usage script for tmux statusline
# Uses Nerd Font icons via UTF-8 byte sequences (bash 3.2 compatible)

ICON_CPU=$(printf '\xef\x8b\x9b')  # U+F2DB nf-fa-microchip

get_cpu_usage() {
	case "$(uname -s)" in
	Darwin)
		cpu=$(/usr/bin/top -l 1 -n 0 2>/dev/null | grep "CPU usage" | awk '{printf "%.0f", $3 + $5}')
		if [ -n "$cpu" ]; then
			echo "${ICON_CPU} ${cpu}%"
		else
			echo ""
		fi
		;;
	Linux)
		if [ -r /proc/stat ]; then
			cpu=$(awk '/^cpu / {idle=$5; total=$2+$3+$4+$5+$6+$7+$8; printf "%.0f", 100*(1-idle/total)}' /proc/stat 2>/dev/null)
			if [ -n "$cpu" ]; then
				echo "${ICON_CPU} ${cpu}%"
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

get_cpu_usage
