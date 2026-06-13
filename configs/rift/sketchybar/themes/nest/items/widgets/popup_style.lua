-- Shared visual language for every bar popup so they read as one system:
-- uniform width/row-height, a compact header with a divider, dim left-column
-- field names, and severity-accented values.
local colors = require("colors")
local settings = require("settings")

local M = {
	width = 240, -- popup content width (all rows + header share this)
	height = 24, -- popup row spacing (bracket popup height)
}

-- Left column (field names / process names): muted so values stand out.
M.label_color = colors.with_alpha(colors.white, 0.5)
-- Right column (values): bright by default; override per-row for severity.
M.value_color = colors.with_alpha(colors.white, 0.95)

-- Map a 0-100 metric (higher = hotter) to an accent color.
function M.severity(pct)
	if pct >= 85 then
		return colors.red
	elseif pct >= 70 then
		return colors.orange
	elseif pct >= 50 then
		return colors.yellow
	else
		return colors.green
	end
end

-- Compact header: centered icon + title with a thin divider underneath.
function M.header(bracket_name, icon_str, title)
	return sbar.add("item", {
		position = "popup." .. bracket_name,
		icon = {
			string = icon_str,
			font = {
				family = settings.font.text,
				style = settings.font.style_map["Bold"],
				size = 13.0,
			},
			color = colors.with_alpha(colors.white, 0.9),
			padding_right = 6,
		},
		label = {
			string = title,
			font = {
				size = 13.0,
				style = settings.font.style_map["Bold"],
			},
			color = colors.with_alpha(colors.white, 0.9),
		},
		width = M.width,
		align = "center",
		background = {
			height = 2,
			color = colors.with_alpha(colors.grey, 0.6),
			y_offset = -13,
		},
	})
end

-- Two-column row: a glyph + name on the left, a value on the right.
-- The glyph is prepended to the name (items have only icon + label slots).
function M.row(bracket_name, glyph, name)
	local left = name and (glyph .. "  " .. name) or glyph
	return sbar.add("item", {
		position = "popup." .. bracket_name,
		icon = {
			string = left,
			align = "left",
			width = M.width * 0.6,
			color = M.label_color,
			padding_left = 8,
		},
		label = {
			string = "—",
			width = M.width * 0.4,
			align = "right",
			color = M.value_color,
			padding_right = 8,
		},
	})
end

return M
