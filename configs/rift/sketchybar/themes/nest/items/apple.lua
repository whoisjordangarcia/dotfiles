local colors = require("colors")
local icons = require("icons")

sbar.add("item", { width = 2 })

local apple = sbar.add("item", {
  icon = {
    font = { size = 15.0 },
    string = icons.apple,
    padding_right = 6,
    padding_left = 6,
    color = colors.white,
  },
  label = { drawing = false },
  background = {
    color = colors.bg2,
    corner_radius = 8,
    height = 24,
  },
  padding_left = 1,
  padding_right = 1,
  click_script = "$CONFIG_DIR/helpers/menus/bin/menus -s 0",
})

sbar.add("item", { width = 4 })
