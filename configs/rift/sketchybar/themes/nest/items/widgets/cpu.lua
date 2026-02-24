local colors = require("colors")
local settings = require("settings")

-- Start the cpu_load event provider binary
sbar.exec(
	"killall cpu_load >/dev/null 2>&1; "
	.. "$CONFIG_DIR/helpers/event_providers/cpu_load/bin/cpu_load cpu_update 2.0"
)

local cpu = sbar.add("item", "widgets.cpu", {
	position = "right",
	icon = {
		string = "CPU",
		font = {
			family = settings.font.text,
			style = settings.font.style_map["Regular"],
			size = 11.0,
		},
		color = colors.with_alpha(colors.text, 0.5),
		padding_right = 4,
	},
	label = {
		font = {
			family = settings.font.numbers,
			size = 11.0,
		},
		color = colors.subtext,
	},
	background = { drawing = false },
	padding_left = 4,
	padding_right = 4,
})

cpu:subscribe("cpu_update", function(env)
	local load = tonumber(env.total_load)
	local color = colors.subtext
	if load > 80 then
		color = colors.red
	elseif load > 60 then
		color = colors.orange
	elseif load > 40 then
		color = colors.yellow
	end

	cpu:set({
		label = { string = env.total_load .. "%", color = color },
	})
end)

sbar.add("item", { position = "right", width = 4 })
