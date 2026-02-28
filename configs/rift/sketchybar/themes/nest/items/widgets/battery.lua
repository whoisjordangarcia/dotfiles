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
		color = colors.with_alpha(colors.white, 0.8),
	},
	background = { drawing = false },
	update_freq = 120,
	padding_left = 4,
	padding_right = 4,
})

battery:subscribe({ "routine", "power_source_change", "system_woke" }, function()
	sbar.exec("pmset -g batt", function(batt_info)
		local icon = "!"
		local label = "?"

		local found, _, charge = batt_info:find("(%d+)%%")
		if found then
			charge = tonumber(charge)
			label = string.format("%02d", charge) .. "%"
		end

		local color = colors.white
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

sbar.add("item", { position = "right", width = 4 })
