local colors = require("colors")
local settings = require("settings")
local proc_popup = require("items.widgets.proc_popup")
local style = require("items.widgets.popup_style")

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

-- Top CPU consumers, fetched only when the popup opens
proc_popup.attach(cpu, {
	title = "CPU",
	icon = "",
	command = "ps axr -o pcpu=,comm= | head -5",
	format = function(pct)
		return string.format("%.1f%%", pct)
	end,
	accent = function(pct)
		return style.severity(pct)
	end,
})

sbar.add("item", { position = "right", width = 4 })
