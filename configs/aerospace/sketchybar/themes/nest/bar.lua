local colors = require("colors")

-- Equivalent to the --bar domain
sbar.bar({
	position = "top",
	height = 40,
	color = 0xff2c2e34, -- More opaque background
	shadow = true,
	--y_offset = -44, -- Move above Aerospace's top gap
	y_offset = 0,
	padding_right = 15,
	padding_left = 15,
})
