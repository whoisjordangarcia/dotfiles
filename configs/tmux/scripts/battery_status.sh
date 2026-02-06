#!/bin/bash

# Battery status script for tmux statusline
# Uses Nerd Font icons via UTF-8 byte sequences (bash 3.2 compatible)

ICON_BATTERY_FULL=$(printf '\xef\x89\x80')   # U+F240 nf-fa-battery_full
ICON_BATTERY_LOW=$(printf '\xef\x89\x83')    # U+F243 nf-fa-battery_quarter
ICON_PLUG=$(printf '\xef\x87\xa6')           # U+F1E6 nf-fa-plug

get_battery_status() {
	case "$(uname -s)" in
	Darwin)
		if command -v pmset >/dev/null 2>&1; then
			battery_info=$(pmset -g batt 2>/dev/null)
			if echo "$battery_info" | grep -q "Battery Power\|AC Power"; then
				percentage=$(echo "$battery_info" | grep -o '[0-9]*%' | head -1 | tr -d '%')

				if [ -n "$percentage" ]; then
					if echo "$battery_info" | grep -q "discharging"; then
						if [ "$percentage" -ge 15 ]; then
							icon="$ICON_BATTERY_FULL"
						else
							icon="$ICON_BATTERY_LOW"
						fi
					elif echo "$battery_info" | grep -q -w "charging"; then
						icon="$ICON_PLUG"
					elif echo "$battery_info" | grep -q "charged"; then
						icon="$ICON_BATTERY_FULL"
					else
						if [ "$percentage" -ge 15 ]; then
							icon="$ICON_BATTERY_FULL"
						else
							icon="$ICON_BATTERY_LOW"
						fi
					fi

					echo "${icon} ${percentage}%"
				else
					echo ""
				fi
			else
				echo ""
			fi
		else
			echo ""
		fi
		;;
	Linux)
		battery_found=false

		for battery in /sys/class/power_supply/BAT*; do
			if [ -d "$battery" ]; then
				battery_found=true

				if [ -r "$battery/capacity" ]; then
					percentage=$(cat "$battery/capacity" 2>/dev/null)
				else
					percentage=""
				fi

				if [ -r "$battery/status" ]; then
					status=$(cat "$battery/status" 2>/dev/null)
				else
					status=""
				fi

				if [ -n "$percentage" ]; then
					case "$status" in
					"Charging")
						icon="$ICON_PLUG"
						;;
					"Full" | "Not charging")
						icon="$ICON_BATTERY_FULL"
						;;
					"Discharging")
						if [ "$percentage" -ge 15 ]; then
							icon="$ICON_BATTERY_FULL"
						else
							icon="$ICON_BATTERY_LOW"
						fi
						;;
					*)
						if [ "$percentage" -ge 15 ]; then
							icon="$ICON_BATTERY_FULL"
						else
							icon="$ICON_BATTERY_LOW"
						fi
						;;
					esac

					echo "${icon} ${percentage}%"
					return 0
				fi
			fi
		done

		if [ "$battery_found" = false ] && command -v acpi >/dev/null 2>&1; then
			acpi_output=$(acpi -b 2>/dev/null | head -1)
			if [ -n "$acpi_output" ]; then
				percentage=$(echo "$acpi_output" | grep -o '[0-9]*%' | tr -d '%')

				if [ -n "$percentage" ]; then
					if echo "$acpi_output" | grep -q -i "charging"; then
						icon="$ICON_PLUG"
					elif echo "$acpi_output" | grep -q -i "full"; then
						icon="$ICON_BATTERY_FULL"
					elif echo "$acpi_output" | grep -q -i "discharging"; then
						if [ "$percentage" -ge 15 ]; then
							icon="$ICON_BATTERY_FULL"
						else
							icon="$ICON_BATTERY_LOW"
						fi
					else
						if [ "$percentage" -ge 15 ]; then
							icon="$ICON_BATTERY_FULL"
						else
							icon="$ICON_BATTERY_LOW"
						fi
					fi

					echo "${icon} ${percentage}%"
					return 0
				fi
			fi
		fi

		echo ""
		;;
	*)
		echo ""
		;;
	esac
}

get_battery_status
