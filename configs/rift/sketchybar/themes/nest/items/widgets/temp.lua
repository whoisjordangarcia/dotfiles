local colors = require("colors")
local settings = require("settings")
local popup_manager = require("items.widgets.popup_manager")
local style = require("items.widgets.popup_style")

-- Start the temp_sensor event provider
sbar.exec(
  "pkill -f temp_sensor.sh >/dev/null 2>&1; "
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
    color = colors.chrome.icon,
    padding_right = 4,
  },
  label = {
    font = {
      family = settings.font.numbers,
      size = 11.0,
    },
    color = colors.chrome.label,
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
  popup = { align = "center", height = style.height },
})

-- Popup items
style.header(temp_bracket.name, "󰔏", "Thermals")
local popup_cpu = style.row(temp_bracket.name, "󰘚", "CPU")
local popup_gpu = style.row(temp_bracket.name, "󰢮", "GPU")
local popup_fan0 = style.row(temp_bracket.name, "󰈐", "Fan 1")
local popup_fan1 = style.row(temp_bracket.name, "󰈐", "Fan 2")

sbar.add("item", "widgets.temp.spacer", { position = "right", width = 4 })

-- Color based on temperature. Used by the popup rows, where a red/orange/yellow
-- legend earns its place.
local function temp_color(t)
  if t >= 90 then return colors.red
  elseif t >= 75 then return colors.orange
  elseif t >= 60 then return colors.yellow
  else return colors.subtext
  end
end

-- The bar item is flat chrome: no severity tint. The popup rows above keep the
-- red/orange/yellow ramp for when you actually open them.

-- Fans live only in the popup, and the SMC dump that exposes them costs ~0.9s
-- (see temp_sensor.sh), so they're read here: once at load to size the rows,
-- then only while the popup is open. One pass reads count (FNum) and RPMs; the
-- `fans` tag keeps sbar.exec from JSON-parsing the output. `[ui8 ]`/`[flt ]`
-- split into two fields, so every value is $4.
local FANS = "smctemp -l 2>/dev/null | awk '/^[[:space:]]*FNum/ {n=$4} /F0Ac/ {f0=$4} /F1Ac/ {f1=$4} "
  .. "END {printf \"fans %.0f %.0f %.0f\", n, f0, f1}'"
local popup_open = false
local fans_pending = false

local function refresh_fans()
  if fans_pending then return end
  fans_pending = true
  sbar.exec(FANS, function(out)
    fans_pending = false
    local count, fan0_rpm, fan1_rpm = tostring(out or ""):match("^fans (%d+) (%d+) (%d+)")
    if not count then return end
    popup_fan0:set({ label = { string = fan0_rpm .. " RPM" } })
    popup_fan1:set({ label = { string = fan1_rpm .. " RPM" } })
    -- Hide fan rows the hardware doesn't have (Mac mini = 1 fan, no F1Ac key).
    -- A count of 0 means the read failed; leave both rows as-is then.
    count = tonumber(count)
    if count > 0 then
      popup_fan0:set({ drawing = count >= 1 })
      popup_fan1:set({ drawing = count >= 2 })
    end
  end)
end
refresh_fans()

-- Subscribe to temp_update events
temp:subscribe("temp_update", function(env)
  local cpu_temp = tonumber(env.cpu_temp) or 0
  local gpu_temp = tonumber(env.gpu_temp) or 0
  local cpu_int = env.cpu_temp_int or "0"

  local color = colors.chrome.label

  -- Update bar item
  temp:set({
    label = { string = cpu_int .. "°", color = color },
    icon = { color = colors.chrome.icon },
  })

  -- Update popup details
  popup_cpu:set({ label = { string = string.format("%.1f°C", cpu_temp), color = temp_color(cpu_temp) } })
  popup_gpu:set({ label = { string = string.format("%.1f°C", gpu_temp), color = temp_color(gpu_temp) } })

  if popup_open then
    refresh_fans()
  end
end)

-- Toggle popup on click
local function hide_details()
  popup_open = false
  temp_bracket:set({ popup = { drawing = false } })
end
local hide = popup_manager.register(hide_details)

local function toggle_details()
  local should_draw = temp_bracket:query().popup.drawing == "off"
  if should_draw then
    popup_manager.close_others(hide)
    popup_open = true
    refresh_fans()
    temp_bracket:set({ popup = { drawing = true } })
  else
    hide_details()
  end
end

temp:subscribe("mouse.clicked", toggle_details)
temp:subscribe("mouse.exited.global", hide_details)
