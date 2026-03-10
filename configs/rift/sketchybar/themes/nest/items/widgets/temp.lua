local colors = require("colors")
local settings = require("settings")

-- Start the temp_sensor event provider
sbar.exec(
  "killall -f temp_sensor.sh >/dev/null 2>&1; "
  .. "$CONFIG_DIR/helpers/event_providers/temp_sensor/temp_sensor.sh temp_update 5.0 &"
)

local popup_width = 220

local temp = sbar.add("item", "widgets.temp", {
  position = "right",
  icon = {
    string = "󰔏",
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Regular"],
      size = 13.0,
    },
    color = colors.with_alpha(colors.text, 0.5),
    padding_right = 4,
  },
  label = {
    font = {
      family = settings.font.numbers,
      size = 11.0,
    },
    color = colors.subtext,
    string = "—°",
  },
  background = { drawing = false },
  padding_left = 4,
  padding_right = 4,
})

-- Background bracket for the popup
local temp_bracket = sbar.add("bracket", "widgets.temp.bracket", {
  temp.name,
}, {
  background = { color = colors.bg1 },
  popup = { align = "center", height = 30 },
})

-- Popup items
local popup_header = sbar.add("item", {
  position = "popup." .. temp_bracket.name,
  icon = {
    string = "󰔏",
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Regular"],
      size = 15.0,
    },
  },
  label = {
    font = {
      size = 15,
      style = settings.font.style_map["Regular"],
    },
    string = "Thermals",
  },
  width = popup_width,
  align = "center",
  background = {
    height = 2,
    color = colors.grey,
    y_offset = -15,
  },
})

local popup_cpu = sbar.add("item", {
  position = "popup." .. temp_bracket.name,
  icon = {
    align = "left",
    string = "CPU",
    width = popup_width / 2,
    color = colors.subtext,
  },
  label = {
    string = "—°C",
    width = popup_width / 2,
    align = "right",
  },
})

local popup_gpu = sbar.add("item", {
  position = "popup." .. temp_bracket.name,
  icon = {
    align = "left",
    string = "GPU",
    width = popup_width / 2,
    color = colors.subtext,
  },
  label = {
    string = "—°C",
    width = popup_width / 2,
    align = "right",
  },
})

local popup_fan_header = sbar.add("item", {
  position = "popup." .. temp_bracket.name,
  icon = {
    string = "󰈐",
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Regular"],
      size = 15.0,
    },
  },
  label = {
    font = {
      size = 15,
      style = settings.font.style_map["Regular"],
    },
    string = "Fans",
  },
  width = popup_width,
  align = "center",
  background = {
    height = 2,
    color = colors.grey,
    y_offset = -15,
  },
})

local popup_fan0 = sbar.add("item", {
  position = "popup." .. temp_bracket.name,
  icon = {
    align = "left",
    string = "Fan 1",
    width = popup_width / 2,
    color = colors.subtext,
  },
  label = {
    string = "— RPM",
    width = popup_width / 2,
    align = "right",
  },
})

local popup_fan1 = sbar.add("item", {
  position = "popup." .. temp_bracket.name,
  icon = {
    align = "left",
    string = "Fan 2",
    width = popup_width / 2,
    color = colors.subtext,
  },
  label = {
    string = "— RPM",
    width = popup_width / 2,
    align = "right",
  },
})

sbar.add("item", { position = "right", width = 4 })

-- Color based on temperature
local function temp_color(t)
  if t >= 90 then return colors.red
  elseif t >= 75 then return colors.orange
  elseif t >= 60 then return colors.yellow
  else return colors.subtext
  end
end

-- Subscribe to temp_update events
temp:subscribe("temp_update", function(env)
  local cpu_temp = tonumber(env.cpu_temp) or 0
  local gpu_temp = tonumber(env.gpu_temp) or 0
  local cpu_int = env.cpu_temp_int or "0"
  local fan0_rpm = env.fan0_rpm or "0"
  local fan1_rpm = env.fan1_rpm or "0"

  local color = temp_color(cpu_temp)

  -- Update bar item
  temp:set({
    label = { string = cpu_int .. "°", color = color },
    icon = { color = color },
  })

  -- Update popup details
  popup_cpu:set({ label = { string = string.format("%.1f°C", cpu_temp), color = temp_color(cpu_temp) } })
  popup_gpu:set({ label = { string = string.format("%.1f°C", gpu_temp), color = temp_color(gpu_temp) } })
  popup_fan0:set({ label = { string = fan0_rpm .. " RPM" } })
  popup_fan1:set({ label = { string = fan1_rpm .. " RPM" } })
end)

-- Toggle popup on click
local function hide_details()
  temp_bracket:set({ popup = { drawing = false } })
end

local function toggle_details()
  local should_draw = temp_bracket:query().popup.drawing == "off"
  if should_draw then
    temp_bracket:set({ popup = { drawing = true } })
  else
    hide_details()
  end
end

temp:subscribe("mouse.clicked", toggle_details)
temp:subscribe("mouse.exited.global", hide_details)
