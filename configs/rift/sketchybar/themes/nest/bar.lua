local colors = require("colors")

sbar.bar({
	position = "top",
	height = 36,
	color = colors.bar.bg,
	blur_radius = 30,
	shadow = false,
	y_offset = 4,
	margin = 8,
	padding_right = 8,
	padding_left = 8,
	corner_radius = 10,
	border_width = 1,
	border_color = colors.bar.border,
	topmost = "window_level",
})
