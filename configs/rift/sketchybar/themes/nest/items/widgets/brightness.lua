local colors = require("colors")
local settings = require("settings")

sbar.exec(
  "killall -f brightness.sh >/dev/null 2>&1; "
  .. "$CONFIG_DIR/helpers/event_providers/brightness/brightness.sh brightness_update 5.0 &"
)

local brightness = sbar.add("item", "widgets.brightness", {
  position = "right",
  icon = {
    string = "󰃟",
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Regular"],
      size = 13.0,
    },
    color = colors.with_alpha(colors.yellow, 0.7),
    padding_right = 2,
  },
  label = {
    font = {
      family = settings.font.numbers,
      size = 11.0,
    },
    color = colors.with_alpha(colors.white, 0.8),
    string = "—%",
  },
  background = { drawing = false },
  padding_left = 4,
  padding_right = 4,
})

local brightness_spacer = sbar.add("item", "widgets.brightness.spacer", { position = "right", width = 4 })

brightness:subscribe("brightness_update", function(env)
  local val = tonumber(env.brightness) or 0
  local visible = val > 0
  local icon = "󰃟"
  local color = colors.with_alpha(colors.yellow, 0.7)

  if val <= 25 then
    icon = "󰃞"
    color = colors.with_alpha(colors.yellow, 0.4)
  elseif val <= 60 then
    icon = "󰃟"
    color = colors.with_alpha(colors.yellow, 0.6)
  else
    icon = "󰃠"
    color = colors.with_alpha(colors.yellow, 0.8)
  end

  brightness:set({
    drawing = visible,
    icon = { string = icon, color = color },
    label = { string = val .. "%" },
  })
  brightness_spacer:set({ drawing = visible })
end)
