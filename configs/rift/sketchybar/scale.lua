-- Uniform pixel scale for the whole bar. SketchyBar has no scale factor of its
-- own, so on a 4K panel driven at 1x (no HiDPI mode — the 120Hz refresh is only
-- available at native resolution) every literal in the themes renders half the
-- intended physical size. Wrapping the four entry points every item routes
-- through beats editing ~120 literals across both themes.
--
-- Override per-invocation with SKETCHYBAR_SCALE=1 (e.g. on the built-in 2x
-- Retina display, where the unscaled sizes are already correct).
local M = {}

-- Default: match the macOS menu bar on the main display. The themes are drawn
-- for a 30px bar, so scale = menubar height / 30 (exactly 1 on a 30px menu bar,
-- which keeps every font and icon at its native size: crisp, no rounding).
local BASE_HEIGHT = 30

-- Runs helpers/menubar_swap with a query flag and returns its output as a number.
function M.query(flag)
	local dir = os.getenv("CONFIG_DIR") or (os.getenv("HOME") .. "/.config/sketchybar")
	local f = io.popen('"' .. dir .. '/helpers/menubar_swap/bin/menubar_swap" ' .. flag .. " 2>/dev/null")
	local n = f and tonumber(f:read("*a"))
	if f then
		f:close()
	end
	return n
end

M.scale = tonumber(os.getenv("SKETCHYBAR_SCALE")) or (M.query("--height") or BASE_HEIGHT) / BASE_HEIGHT

-- Extra multiplier for font sizes (`size`) only, on top of `scale`: matching the
-- menu bar's height leaves the themes' 11-13px text too small to read.
M.font_scale = tonumber(os.getenv("SKETCHYBAR_FONT_SCALE")) or 1.2

-- border_width is deliberately absent: hairlines read as hairlines at any size,
-- and rounding 1 * scale would thicken every border by a whole pixel.
local SCALED = {
	size = true,
	height = true,
	width = true,
	margin = true,
	padding_left = true,
	padding_right = true,
	corner_radius = true,
	y_offset = true,
}

-- Returns a scaled copy; never mutates. sbar.set runs on every widget update,
-- and scaling in place would compound on each tick.
function M.scale_props(t)
	local out = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			out[k] = M.scale_props(v)
		elseif k == "size" and type(v) == "number" then
			out[k] = math.floor(v * M.scale * M.font_scale + 0.5)
		elseif SCALED[k] and type(v) == "number" then
			out[k] = math.floor(v * M.scale + 0.5)
		else
			out[k] = v
		end
	end
	return out
end

function M.install(bar)
	if M.scale == 1 and M.font_scale == 1 then
		return
	end
	for _, name in ipairs({ "bar", "default", "add", "set" }) do
		local orig = bar[name]
		bar[name] = function(...)
			local n = select("#", ...)
			local args = table.pack(...)
			for i = 1, n do
				if type(args[i]) == "table" then
					args[i] = M.scale_props(args[i])
				end
			end
			return orig(table.unpack(args, 1, n))
		end
	end
end

return M
