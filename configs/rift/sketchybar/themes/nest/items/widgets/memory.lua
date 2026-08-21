local colors = require("colors")
local settings = require("settings")
local proc_popup = require("items.widgets.proc_popup")
local style = require("items.widgets.popup_style")

local memory = sbar.add("item", "widgets.memory", {
	position = "right",
	icon = {
		string = "󰍛",
		font = {
			family = settings.font.text,
			style = settings.font.style_map["Regular"],
			size = 11.0,
		},
		color = colors.chrome.icon,
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
			memory:set({
				label = { string = string.format("%02d", used) .. "%", color = colors.chrome.label },
			})
		end
	end)
end)

-- Top memory consumers, fetched only when the popup opens (ps rss is in KB)
proc_popup.attach(memory, {
	title = "Memory",
	icon = "󰍛",
	command = "ps axm -o rss=,comm= | head -5",
	format = function(kb)
		if kb >= 1048576 then
			return string.format("%.1f GB", kb / 1048576)
		end
		return string.format("%.0f MB", kb / 1024)
	end,
	-- Accent by absolute footprint: >4 GB hot, >2 GB warm.
	accent = function(kb)
		if kb >= 4194304 then
			return colors.red
		elseif kb >= 2097152 then
			return colors.orange
		end
		return style.value_color
	end,
})

sbar.add("item", "widgets.memory.spacer", { position = "right", width = 4 })
