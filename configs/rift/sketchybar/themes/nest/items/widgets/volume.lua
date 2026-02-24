local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

local volume = sbar.add("item", "widgets.volume", {
	position = "right",
	icon = {
		string = icons.volume._100,
		font = {
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
	padding_left = 4,
	padding_right = 4,
})

volume:subscribe("volume_change", function(env)
	local vol = tonumber(env.INFO)
	local icon = icons.volume._0
	if vol > 60 then
		icon = icons.volume._100
	elseif vol > 30 then
		icon = icons.volume._66
	elseif vol > 10 then
		icon = icons.volume._33
	elseif vol > 0 then
		icon = icons.volume._10
	end

	volume:set({
		icon = { string = icon },
		label = { string = vol .. "%" },
	})
end)

sbar.add("item", { position = "right", width = 4 })
