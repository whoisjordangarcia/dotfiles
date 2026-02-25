local colors = require("colors")

sbar.bar({
	position = "top",
	height = 30,
	color = colors.bar.bg,
	blur_radius = 30,
	shadow = false,
	y_offset = 6,
	margin = 10,
	padding_right = 4,
	padding_left = 4,
	corner_radius = 10,
	border_width = 1,
	border_color = colors.bar.border,
	topmost = "window_level",
})
