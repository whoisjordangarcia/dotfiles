local colors = require("colors")
local settings = require("settings")
local popup_manager = require("items.widgets.popup_manager")
local style = require("items.widgets.popup_style")

local STATS = "python3 $HOME/dev/dotfiles/configs/ai-stats/ai_stats.py --json 2>/dev/null"

local METER_SEGMENTS = 5

local function meter(pct)
	local filled = math.floor(math.min(pct, 100) / 100 * METER_SEGMENTS + 0.5)
	return string.rep("▰", filled) .. string.rep("▱", METER_SEGMENTS - filled)
end

-- Centred, except with a notched laptop display active, where the centre is
-- under the notch: then it follows front_app on the left. Decided at load;
-- display-change.sh reloads the bar on hotplug.
local POS = require("scale").notch and "left" or "center"

-- Gap from front_app, which sits just before it on the left.
sbar.add("item", "widgets.claude.lead", { position = POS, width = 10, drawing = POS == "left" })

local claude = sbar.add("item", "widgets.claude", {
	position = POS,
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
	label = { drawing = false },
	background = { drawing = false },
	-- The stats script parses transcripts (1-3 s); don't poll it harder.
	update_freq = 300,
	padding_left = 4,
	padding_right = 4,
})

local week = sbar.add("item", "widgets.claude.week", {
	position = POS,
	label = {
		string = "—",
		font = { family = settings.font.numbers, size = 11.0 },
		color = colors.chrome.label,
	},
	background = { drawing = false },
	padding_left = 4,
	padding_right = 4,
})

local bracket = sbar.add("bracket", "widgets.claude.bracket", { claude.name, week.name }, {
	background = { color = colors.bg1 },
	popup = { align = "center", height = style.height },
})

style.header(bracket.name, "󰚩", "Claude")
local session_row = style.row(bracket.name, "󰔟", "Session 5h")
local week_row = style.row(bracket.name, "󰃭", "Week")
local today_row = style.row(bracket.name, "󰃶", "Today")
local week_spend_row = style.row(bracket.name, "󰄫", "Week spend")
local month_spend_row = style.row(bracket.name, "󰸗", "Month spend")

local function limit_color(pct)
	if pct >= 80 then
		return colors.red
	elseif pct >= 50 then
		return colors.yellow
	end
	return colors.chrome.label
end

local function money(period)
	if type(period) ~= "table" or type(period.cost_usd) ~= "number" then
		return "$—"
	elseif period.cost_usd >= 1000 then
		return string.format("$%.1fk", period.cost_usd / 1000)
	end
	return string.format("$%.0f", period.cost_usd)
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

-- Clicking the 7d item steps through these; the last shows all three.
local COST_VIEWS = { { "today" }, { "week" }, { "month" }, { "today", "week", "month" } }
local COST_LABELS = { today = "d", week = "w", month = "m" }
local cost_view = 1
local last_stats

local function cost_text(stats)
	local parts = {}
	for _, key in ipairs(COST_VIEWS[cost_view]) do
		table.insert(parts, COST_LABELS[key] .. " " .. money(stats[key]))
	end
	return table.concat(parts, " · ")
end

local function render_week(stats)
	local seven_day = (type(stats.limits) == "table" and stats.limits or {}).seven_day
	local cost = cost_text(stats)
	if type(seven_day) == "table" and type(seven_day.used_percentage) == "number" then
		week:set({ label = {
			string = string.format("7d %s %.0f%% · %s", meter(seven_day.used_percentage), seven_day.used_percentage, cost),
			color = limit_color(seven_day.used_percentage),
		} })
	else
		week:set({ label = { string = cost, color = colors.with_alpha(colors.text, 0.3) } })
	end
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
			week:set({ label = { string = "—", color = colors.with_alpha(colors.text, 0.3) } })
			return
		end

		local limits = type(stats.limits) == "table" and stats.limits or {}
		last_stats = stats
		render_week(stats)

		session_row:set({ label = { string = limit_text(limits.five_hour) } })
		week_row:set({ label = { string = limit_text(limits.seven_day) } })
		today_row:set({ label = { string = spend_text(stats.today) } })
		week_spend_row:set({ label = { string = spend_text(stats.week) } })
		month_spend_row:set({ label = { string = spend_text(stats.month) } })
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

week:subscribe("mouse.clicked", function()
	cost_view = cost_view % #COST_VIEWS + 1
	if last_stats then
		render_week(last_stats)
	end
end)

sbar.add("item", "widgets.claude.spacer", { position = POS, width = 4, drawing = POS == "left" })
