local settings = require("settings")
local colors = require("colors")
local popup_manager = require("items.widgets.popup_manager")

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
		color = colors.with_alpha(colors.grey, 0.35),
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

-- Simple month calendar (`cal` output), fetched only when the popup opens
local cal_bracket = sbar.add("bracket", "calendar.bracket", { cal.name }, {
	popup = { align = "center", height = 15 },
})

local cal_rows = {}
for i = 1, 8 do
	cal_rows[i] = sbar.add("item", {
		position = "popup." .. cal_bracket.name,
		drawing = false,
		icon = { drawing = false },
		label = {
			-- monospace bitmap font keeps the day columns aligned. Width must
			-- fit the widest row (~22 chars incl. pad) or `cal`'s last column
			-- clips; centered with small padding to minimize dead space.
			font = { family = settings.font.numbers, size = 12.0 },
			color = colors.white,
			align = "center",
			width = 178,
		},
		padding_left = 4,
		padding_right = 4,
	})
end

local function hide_calendar()
	cal_bracket:set({ popup = { drawing = false } })
end
local hide = popup_manager.register(hide_calendar)

cal:subscribe("mouse.clicked", function()
	if cal_bracket:query().popup.drawing ~= "off" then
		hide_calendar()
		return
	end
	popup_manager.close_others(hide)
	sbar.exec("cal", function(out)
		local i = 1
		-- Right-aligned 2-char day, as `cal` prints it ("15" / " 5")
		local daystr = string.format("%2d", tonumber(os.date("%d")))
		for line in (out or ""):gmatch("[^\r\n]+") do
			if i > 8 then
				break
			end
			-- Uniform leading/trailing pad so today can be matched (and
			-- bracketed) even in the first or last column; swapping the
			-- surrounding spaces for [ ] keeps the columns aligned.
			local row = " " .. line .. " "
			if i > 2 then
				row = row:gsub(" " .. daystr .. " ", "[" .. daystr .. "]", 1)
			end
			cal_rows[i]:set({ drawing = true, label = { string = row } })
			i = i + 1
		end
		for j = i, 8 do
			cal_rows[j]:set({ drawing = false })
		end
		cal_bracket:set({ popup = { drawing = true } })
	end)
end)
cal:subscribe("mouse.exited.global", hide_calendar)

sbar.add("item", { position = "right", width = 4 })
