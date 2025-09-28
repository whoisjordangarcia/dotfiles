#!/bin/bash

# Battery status script for tmux statusline
# Supports macOS and Linux platforms with improved icons and charging status

get_battery_status() {
	case "$(uname -s)" in
	Darwin)
		# macOS - use pmset command for detailed battery info
		if command -v pmset >/dev/null 2>&1; then
			battery_info=$(pmset -g batt 2>/dev/null)
			if echo "$battery_info" | grep -q "Battery Power\|AC Power"; then
				# Extract percentage
				percentage=$(echo "$battery_info" | grep -o '[0-9]*%' | head -1 | tr -d '%')

				if [ -n "$percentage" ]; then
					# Determine charging status and icon
					if echo "$battery_info" | grep -q "discharging"; then
						# On battery power - show battery level icon
						if [ "$percentage" -ge 15 ]; then
							icon="🔋"
						else
							icon="🪫"
						fi
					elif echo "$battery_info" | grep -q -w "charging"; then
						# Charging - show plug icon
						icon="🔌"
					elif echo "$battery_info" | grep -q "charged"; then
						# Fully charged - show battery icon
						icon="🔋"
					else
						# Default - show battery level icon
						if [ "$percentage" -ge 15 ]; then
							icon="🔋"
						else
							icon="🪫"
						fi
					fi

					echo "${icon}${percentage}%"
				else
					echo ""
				fi
			else
				# Desktop Mac - no battery
				echo ""
			fi
		else
			echo ""
		fi
		;;
	Linux)
		# Linux - check multiple battery paths
		battery_found=false

		# Check /sys/class/power_supply for battery info
		for battery in /sys/class/power_supply/BAT*; do
			if [ -d "$battery" ]; then
				battery_found=true

				# Read capacity
				if [ -r "$battery/capacity" ]; then
					percentage=$(cat "$battery/capacity" 2>/dev/null)
				else
					percentage=""
				fi

				# Read status
				if [ -r "$battery/status" ]; then
					status=$(cat "$battery/status" 2>/dev/null)
				else
					status=""
				fi

				if [ -n "$percentage" ]; then
					# Determine charging status and icon
					case "$status" in
					"Charging")
						icon="🔌"
						;;
					"Full" | "Not charging")
						icon="🔋"
						;;
					"Discharging")
						# On battery power - show battery level icon
						if [ "$percentage" -ge 15 ]; then
							icon="🔋"
						else
							icon="🪫"
						fi
						;;
					*)
						# Default - show battery level icon
						if [ "$percentage" -ge 15 ]; then
							icon="🔋"
						else
							icon="🪫"
						fi
						;;
					esac

					echo "${icon}${percentage}%"
					return 0
				fi
			fi
		done

		# If no battery found or readable, try acpi command
		if [ "$battery_found" = false ] && command -v acpi >/dev/null 2>&1; then
			acpi_output=$(acpi -b 2>/dev/null | head -1)
			if [ -n "$acpi_output" ]; then
				percentage=$(echo "$acpi_output" | grep -o '[0-9]*%' | tr -d '%')

				if [ -n "$percentage" ]; then
					# Determine charging status and icon
					if echo "$acpi_output" | grep -q -i "charging"; then
						icon="🔌"
					elif echo "$acpi_output" | grep -q -i "full"; then
						icon="🔋"
					elif echo "$acpi_output" | grep -q -i "discharging"; then
						# On battery power - show battery level icon
						if [ "$percentage" -ge 15 ]; then
							icon="🔋"
						else
							icon="🪫"
						fi
					else
						# Default - show battery level icon
						if [ "$percentage" -ge 15 ]; then
							icon="🔋"
						else
							icon="🪫"
						fi
					fi

					echo "${icon}${percentage}%"
					return 0
				fi
			fi
		fi

		# No battery found or not a laptop
		echo ""
		;;
	*)
		echo ""
		;;
	esac
}

get_battery_status
