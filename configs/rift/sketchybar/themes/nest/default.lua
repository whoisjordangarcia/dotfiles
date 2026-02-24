local settings = require("settings")
local colors = require("colors")

sbar.default({
  updates = "when_shown",
  icon = {
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Semibold"],
      size = 14.0,
    },
    color = colors.white,
    padding_left = settings.paddings,
    padding_right = settings.paddings,
    background = { image = { corner_radius = 6 } },
  },
  label = {
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Regular"],
      size = 14.0,
    },
    color = colors.with_alpha(colors.white, 0.85),
    padding_left = settings.paddings,
    padding_right = settings.paddings,
  },
  background = {
    height = 24,
    corner_radius = 6,
    border_width = 0,
    border_color = colors.transparent,
    image = {
      corner_radius = 6,
    },
  },
  popup = {
    background = {
      border_width = 1,
      corner_radius = 8,
      border_color = colors.popup.border,
      color = colors.popup.bg,
      shadow = { drawing = true },
    },
    blur_radius = 50,
  },
  padding_left = 2,
  padding_right = 2,
  scroll_texts = true,
})
