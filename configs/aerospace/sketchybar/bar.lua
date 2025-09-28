local colors = require("colors")

-- Equivalent to the --bar domain
sbar.bar({
	position = "top",
	height = 32,
	color = 0xff2c2e34,  -- More opaque background
	shadow = true,
	y_offset = -30,  -- Move above Aerospace's top gap
	padding_right = 2,
	padding_left = 2,
})
