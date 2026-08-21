local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

local battery = sbar.add("item", "widgets.battery", {
	position = "right",
	icon = {
		font = {
			style = settings.font.style_map["Regular"],
			size = 11.0,
		},
		padding_right = 2,
	},
	label = {
		font = {
			family = settings.font.numbers,
			size = 11.0,
		},
		color = colors.chrome.label,
	},
	background = { drawing = false },
	update_freq = 120,
	padding_left = 4,
	padding_right = 4,
})

-- `ioreg -a` (plist) reports InstantAmperage as a *signed* integer. The default
-- text form prints negative current as an unsigned 64-bit value, and Lua's
-- doubles can't round-trip that back (ULP near 2^64 is 2048, so -777 becomes 0).
-- One ioreg call, two cheap plutil extracts; prints "<mA>\n<mV>".
local POWER_QUERY = 'p=$(ioreg -arn AppleSmartBattery -w0); '
	.. [[printf '%s' "$p" | plutil -extract 0.InstantAmperage raw -o - - 2>/dev/null; ]]
	.. [[printf '%s' "$p" | plutil -extract 0.Voltage raw -o - - 2>/dev/null]]

-- ponytail: battery flow (draw when discharging, charge rate on AC), not total
-- SoC package power — that needs `sudo powermetrics`, unusable from the bar.
local power = sbar.add("item", "widgets.battery.power", {
	position = "right",
	icon = { drawing = false },
	label = {
		font = {
			family = settings.font.numbers,
			size = 11.0,
		},
		color = colors.chrome.label,
	},
	background = { drawing = false },
	update_freq = 15,
	padding_left = 4,
	padding_right = 2,
})

power:subscribe({ "routine", "power_source_change", "system_woke" }, function()
	sbar.exec(POWER_QUERY, function(out)
		local milliamps, millivolts = out:match("(-?%d+)%s+(%d+)")
		-- No battery (desktop) or an unreadable gauge: both extracts print nothing.
		if not milliamps then
			power:set({ drawing = false })
			return
		end

		local amps = tonumber(milliamps)
		power:set({
			drawing = true,
			label = {
				string = string.format("%.1fW", math.abs(amps) * tonumber(millivolts) / 1e6),
				color = amps > 0 and colors.green or colors.chrome.label,
			},
		})
	end)
end)

local battery_spacer = sbar.add("item", "widgets.battery.spacer", { position = "right", width = 4 })

battery:subscribe({ "routine", "power_source_change", "system_woke" }, function()
	sbar.exec("pmset -g batt", function(batt_info)
		-- Desktops (Mac mini/Studio) have no InternalBattery line — hide entirely.
		if not batt_info:find("InternalBattery") then
			battery:set({ drawing = false })
			battery_spacer:set({ drawing = false })
			return
		end

		local icon = "!"
		local label = "?"

		local found, _, charge = batt_info:find("(%d+)%%")
		if found then
			charge = tonumber(charge)
			label = string.format("%02d", charge) .. "%"
		end

		local color = colors.chrome.icon
		local charging = batt_info:find("AC Power")

		if charging then
			icon = icons.battery.charging
			color = colors.green
		else
			if found and charge > 80 then
				icon = icons.battery._100
			elseif found and charge > 60 then
				icon = icons.battery._75
			elseif found and charge > 40 then
				icon = icons.battery._50
			elseif found and charge > 20 then
				icon = icons.battery._25
				color = colors.orange
			else
				icon = icons.battery._0
				color = colors.red
			end
		end

		battery:set({
			icon = { string = icon, color = color },
			label = { string = label },
		})
	end)
end)
