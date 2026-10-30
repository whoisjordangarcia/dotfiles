local colors = require("colors")
local popup_manager = require("items.widgets.popup_manager")
local style = require("items.widgets.popup_style")

-- Attaches a click-to-open popup to a widget listing its top processes.
-- Rows are populated only when the popup opens — no background polling.
--
-- opts:
--   title   - popup header text
--   icon    - popup header icon
--   command - shell command emitting "<value> <command-path>" lines
--   format  - function(value) -> display string for the right column
--   accent  - optional function(value) -> color for the value (severity)
local M = {}

local row_count = 5
-- Subtle rank markers so the busiest process reads first.
local rank_glyph = { "󰬺", "󰬻", "󰬼", "󰬽", "󰬾" }

function M.attach(item, opts)
	local bracket = sbar.add("bracket", item.name .. ".bracket", { item.name }, {
		background = { color = colors.bg1 },
		popup = { align = "center", height = style.height },
	})

	-- Process names are longer than the field-name popups this style was built
	-- for, so this popup is wider and its name column takes 0.72, not 0.6.
	-- max_chars counts the rank glyph and its two spaces, and must fit the
	-- column at the scaled font or the name runs into the value.
	local width = 320
	style.header(bracket.name, opts.icon, opts.title):set({ width = width })

	local rows = {}
	for i = 1, row_count do
		rows[i] = style.row(bracket.name, rank_glyph[i], "")
		rows[i]:set({
			icon = { max_chars = 26, width = width * 0.72 },
			label = { width = width * 0.28 },
		})
	end

	local function refresh()
		sbar.exec(opts.command, function(out)
			local i = 1
			for line in (out or ""):gmatch("[^\r\n]+") do
				if i > row_count then
					break
				end
				local value, path = line:match("^%s*([%d%.]+)%s+(.+)$")
				if value then
					local name = path:match("([^/]+)%s*$") or path
					local num = tonumber(value)
					rows[i]:set({
						icon = { string = rank_glyph[i] .. "  " .. name, color = style.label_color },
						label = {
							string = opts.format(num),
							color = opts.accent and opts.accent(num) or style.value_color,
						},
					})
					i = i + 1
				end
			end
			for j = i, row_count do
				rows[j]:set({
					icon = { string = rank_glyph[j] .. "  —", color = style.label_color },
					label = { string = "—", color = style.value_color },
				})
			end
		end)
	end

	local function hide_details()
		bracket:set({ popup = { drawing = false } })
	end
	local hide = popup_manager.register(hide_details)

	item:subscribe("mouse.clicked", function()
		local should_draw = bracket:query().popup.drawing == "off"
		if should_draw then
			popup_manager.close_others(hide)
			refresh()
			bracket:set({ popup = { drawing = true } })
		else
			hide_details()
		end
	end)
	item:subscribe("mouse.exited.global", hide_details)
end

return M
