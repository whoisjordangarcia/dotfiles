local colors = require("colors")
local settings = require("settings")

local memory = sbar.add("item", "widgets.memory", {
	position = "right",
	icon = {
		string = "󰍛",
		font = {
			family = settings.font.text,
			style = settings.font.style_map["Regular"],
			size = 11.0,
		},
		color = colors.with_alpha(colors.white, 0.7),
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
	update_freq = 10,
	padding_left = 4,
	padding_right = 4,
})

memory:subscribe({ "routine", "forced" }, function()
	sbar.exec("memory_pressure | grep 'System-wide'", function(result)
		if not result or result == "" then return end
		local found, _, pct = result:find("(%d+)%%")
		if found then
			local free = tonumber(pct)
			local used = 100 - free
			local color = colors.with_alpha(colors.white, 0.8)
			if used > 80 then
				color = colors.red
			elseif used > 60 then
				color = colors.orange
			end
			memory:set({
				label = { string = string.format("%02d", used) .. "%", color = color },
			})
		end
	end)
end)

sbar.add("item", { position = "right", width = 4 })
