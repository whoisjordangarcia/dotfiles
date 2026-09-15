local colors = require("colors")
local settings = require("settings")
local popup_manager = require("items.widgets.popup_manager")
local style = require("items.widgets.popup_style")

local STATS = "python3 $HOME/dev/dotfiles/configs/claude/claude_stats.py --json 2>/dev/null"

local claude = sbar.add("item", "widgets.claude", {
	position = "right",
	icon = {
		string = "󰚩",
		font = {
			family = settings.font.text,
			style = settings.font.style_map["Regular"],
			size = 11.0,
		},
		color = colors.chrome.icon,
		padding_right = 2,
	},
	label = {
		string = "—",
		font = {
			family = settings.font.numbers,
			size = 11.0,
		},
		color = colors.chrome.label,
	},
	background = { drawing = false },
	-- The stats script parses transcripts (1-3 s); don't poll it harder.
	update_freq = 300,
	padding_left = 4,
	padding_right = 4,
})

local bracket = sbar.add("bracket", "widgets.claude.bracket", { claude.name }, {
	background = { color = colors.bg1 },
	popup = { align = "center", height = style.height },
})

style.header(bracket.name, "󰚩", "Claude")
local session_row = style.row(bracket.name, "󰔟", "Session 5h")
local week_row = style.row(bracket.name, "󰃭", "Week")
local today_row = style.row(bracket.name, "󰃶", "Today")
local week_spend_row = style.row(bracket.name, "󰄫", "Week spend")

local function week_color(pct)
	if pct >= 80 then
		return colors.red
	elseif pct >= 50 then
		return colors.yellow
	end
	return colors.chrome.label
end

local function tokens(n)
	if n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	end
	return string.format("%.0fk", n / 1e3)
end

-- JSON null arrives as nil or a non-number, so every field is type-checked.
local function limit_text(limit)
	if type(limit) ~= "table" or type(limit.used_percentage) ~= "number" then
		return "—"
	end
	local text = string.format("%.0f%%", limit.used_percentage)
	if type(limit.projected_percentage) == "number" then
		text = text .. string.format(" → %.0f%%", limit.projected_percentage)
	end
	return text
end

local function spend_text(period)
	if type(period) ~= "table" or type(period.cost_usd) ~= "number" then
		return "—"
	end
	return string.format("%s · $%.0f", tokens(tonumber(period.tokens) or 0), period.cost_usd)
end

claude:subscribe({ "routine", "forced", "system_woke" }, function()
	sbar.exec(STATS, function(stats)
		if type(stats) ~= "table" then
			claude:set({ label = { string = "—", color = colors.with_alpha(colors.text, 0.3) } })
			return
		end

		local limits = type(stats.limits) == "table" and stats.limits or {}
		local week = limits.seven_day
		local today = type(stats.today) == "table" and stats.today or {}
		local cost = type(today.cost_usd) == "number" and string.format("$%.0f", today.cost_usd) or "$—"

		if type(week) == "table" and type(week.used_percentage) == "number" then
			claude:set({
				label = {
					string = string.format("W %.0f%% · %s", week.used_percentage, cost),
					color = week_color(week.used_percentage),
				},
			})
		else
			claude:set({ label = { string = cost, color = colors.with_alpha(colors.text, 0.3) } })
		end

		session_row:set({ label = { string = limit_text(limits.five_hour) } })
		week_row:set({ label = { string = limit_text(week) } })
		today_row:set({ label = { string = spend_text(stats.today) } })
		week_spend_row:set({ label = { string = spend_text(stats.week) } })
	end)
end)

local function hide_details()
	bracket:set({ popup = { drawing = false } })
end
local hide = popup_manager.register(hide_details)

claude:subscribe("mouse.clicked", function()
	if bracket:query().popup.drawing == "off" then
		popup_manager.close_others(hide)
		bracket:set({ popup = { drawing = true } })
	else
		hide_details()
	end
end)
claude:subscribe("mouse.exited.global", hide_details)

sbar.add("item", "widgets.claude.spacer", { position = "right", width = 4 })
