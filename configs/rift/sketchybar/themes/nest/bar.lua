local colors = require("colors")

sbar.bar({
	position = "top",
	height = 30,
	color = colors.bar.bg,
	blur_radius = 30,
	shadow = false,
	-- Flush, full-width, square: sits where the macOS menu bar would.
	y_offset = 0,
	margin = 0,
	padding_right = 4,
	padding_left = 4,
	corner_radius = 0,
	border_width = 0,
	topmost = "window_level",
})

-- Top edge swaps in the auto-hidden macOS menu bar (helpers/menubar_swap):
-- SketchyBar hides while the pointer is up there, returns once it leaves.
-- It slides the bar between y_offsets, passed in already scaled (the helper
-- calls the sketchybar CLI directly, outside scale.lua's wrapper).
local scale = require("scale").scale
local bar_h = math.floor(30 * scale + 0.5)
sbar.exec("killall menubar_swap >/dev/null 2>&1; $CONFIG_DIR/helpers/menubar_swap/bin/menubar_swap "
	.. (bar_h + 10) .. " 0 " .. -(bar_h + 6) .. " &")

-- rift can't see the bar, so hand it the top gap: bar height + the usual 10px.
sbar.exec("/opt/homebrew/bin/rift-cli execute config set-outer-gaps " .. (bar_h + 10) .. " 10 10 10")
