local colors = require("colors")
local settings = require("settings")

local front_app = sbar.add("item", "front_app", {
  display = "active",
  icon = { drawing = false },
  label = {
    font = {
      style = settings.font.style_map["Semibold"],
      size = 11.0,
    },
    color = colors.with_alpha(colors.white, 0.7),
  },
  padding_left = 6,
  updates = true,
})

front_app:subscribe("front_app_switched", function(env)
  front_app:set({ label = { string = env.INFO } })
end)

front_app:subscribe("workspace_app_change", function(env)
  local has_app = env.HAS_APP == "true"
  front_app:set({ drawing = has_app })
end)

front_app:subscribe("mouse.clicked", function(env)
  sbar.trigger("swap_menus_and_spaces")
end)
