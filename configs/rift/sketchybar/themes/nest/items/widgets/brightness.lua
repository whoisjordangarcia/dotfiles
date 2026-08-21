local colors = require("colors")
local settings = require("settings")

sbar.exec(
  "pkill -f brightness.sh >/dev/null 2>&1; "
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
    color = colors.chrome.icon,
    padding_right = 2,
  },
  label = {
    font = {
      family = settings.font.numbers,
      size = 11.0,
    },
    color = colors.chrome.label,
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
  -- Flat chrome; the level shows in the glyph, not the tint.
  local color = colors.chrome.icon

  if val <= 25 then
    icon = "󰃞"
  elseif val <= 60 then
    icon = "󰃟"
  else
    icon = "󰃠"
  end

  brightness:set({
    drawing = visible,
    icon = { string = icon, color = color },
    label = { string = val .. "%" },
  })
  brightness_spacer:set({ drawing = visible })
end)
