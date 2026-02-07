return {
  paddings = 3,
  group_paddings = 5,

  icons = "sf-symbols", -- alternatively available: NerdFont

  -- This is a font configuration for SF Pro and SF Mono (installed manually)
  -- font = require("helpers.default_font"),

  -- JetBrainsMono Nerd Font (used for Aerospace compatibility)
  font = {
    text = "JetBrainsMono Nerd Font",
    numbers = "JetBrainsMono Nerd Font",
    style_map = {
      ["Regular"] = "Regular",
      ["Semibold"] = "Medium",
      ["Bold"] = "SemiBold",
      ["Heavy"] = "Bold",
      ["Black"] = "ExtraBold",
    },
  },
}
