local settings = require("settings")
local colors = require("colors")

local cal = sbar.add("item", {
	icon = {
		color = colors.with_alpha(colors.white, 0.6),
		padding_left = 8,
		font = {
			family = settings.font.text,
			style = settings.font.style_map["Semibold"],
			size = 11.0,
		},
	},
	label = {
		color = colors.white,
		padding_right = 8,
		width = 76,
		align = "right",
		font = {
			family = settings.font.numbers,
			size = 11.0,
		},
	},
	position = "right",
	update_freq = 30,
	padding_left = 2,
	padding_right = 2,
	background = {
		color = colors.bg2,
		corner_radius = 8,
		height = 24,
	},
})

cal:subscribe({ "forced", "routine", "system_woke" }, function()
	cal:set({
		icon = os.date("%a %d %b"),
		label = os.date("%I:%M %p"),
	})
end)

sbar.add("item", { position = "right", width = 4 })
