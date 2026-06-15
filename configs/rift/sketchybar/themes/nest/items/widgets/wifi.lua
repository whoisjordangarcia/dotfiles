local icons = require("icons")
local colors = require("colors")
local settings = require("settings")
local popup_manager = require("items.widgets.popup_manager")
local style = require("items.widgets.popup_style")

-- Active interface is detected from the default route (en0 on Wi-Fi-only
-- machines, often en1+ on docks/Mac mini ethernet) so the throughput
-- provider measures the link that's actually carrying traffic.
local net_iface = "en0"

sbar.exec("route -n get default 2>/dev/null | awk '/interface:/{print $2}'", function(iface)
	iface = (iface or ""):match("^%s*(.-)%s*$")
	if iface ~= "" then
		net_iface = iface
	end
	sbar.exec(
		"killall network_load >/dev/null 2>&1; "
			.. "$CONFIG_DIR/helpers/event_providers/network_load/bin/network_load "
			.. net_iface
			.. " network_update 2.0"
	)
end)

-- Signal provider: compiled CoreWLAN reader, RSSI + SSID every 10s.
sbar.exec(
	"pkill -f wifi_signal.sh >/dev/null 2>&1; "
		.. "$CONFIG_DIR/helpers/event_providers/wifi_signal/wifi_signal.sh wifi_signal_update 10.0 &"
)

local popup_width = 250

-- SSID from the signal provider; may be empty on macOS 14+ without
-- Location Services permission, so connectivity keys off RSSI instead.
local last_ssid = ""

local wifi_up = sbar.add("item", "widgets.wifi1", {
	position = "right",
	padding_left = -5,
	width = 0,
	icon = {
		padding_right = 0,
		font = {
			style = settings.font.style_map["Bold"],
			size = 9.0,
		},
		string = icons.wifi.upload,
	},
	label = {
		font = {
			family = settings.font.numbers,
			style = settings.font.style_map["Bold"],
			size = 9.0,
		},
		color = colors.red,
		string = "??? Bps",
	},
	y_offset = 4,
})

local wifi_down = sbar.add("item", "widgets.wifi2", {
	position = "right",
	padding_left = -5,
	icon = {
		padding_right = 0,
		font = {
			style = settings.font.style_map["Bold"],
			size = 9.0,
		},
		string = icons.wifi.download,
	},
	label = {
		font = {
			family = settings.font.numbers,
			style = settings.font.style_map["Bold"],
			size = 9.0,
		},
		color = colors.blue,
		string = "??? Bps",
	},
	y_offset = -4,
})

local wifi = sbar.add("item", "widgets.wifi", {
	position = "right",
	icon = {
		string = icons.wifi.signal._0,
		font = {
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
		color = colors.with_alpha(colors.white, 0.8),
		string = "—%",
	},
})

-- Background around the item
local wifi_bracket = sbar.add("bracket", "widgets.wifi.bracket", {
	wifi.name,
	wifi_up.name,
	wifi_down.name,
}, {
	background = { color = colors.bg1 },
	popup = { align = "center", height = style.height },
})

style.header(wifi_bracket.name, icons.wifi.signal._4, "Wi-Fi")

local ssid = style.row(wifi_bracket.name, "󰖩", "Network")
local signal_row = style.row(wifi_bracket.name, "󰤨", "Signal")
local ip = style.row(wifi_bracket.name, "", "IP")
local mask = style.row(wifi_bracket.name, "󰩠", "Subnet")
local router = style.row(wifi_bracket.name, icons.wifi.router, "Router")
local hostname = style.row(wifi_bracket.name, "󰇄", "Host")

sbar.add("item", { position = "right", width = settings.group_paddings })

wifi_up:subscribe("network_update", function(env)
	local up_color = (env.upload == "000 Bps") and colors.grey or colors.red
	local down_color = (env.download == "000 Bps") and colors.grey or colors.blue
	wifi_up:set({
		icon = { color = up_color },
		label = {
			string = env.upload,
			color = up_color,
		},
	})
	wifi_down:set({
		icon = { color = down_color },
		label = {
			string = env.download,
			color = down_color,
		},
	})
end)

-- RSSI (dBm) -> 0-4 bars. 0 dBm means Wi-Fi off / not associated.
local function signal_bars(rssi)
	if rssi == 0 then
		return 0
	elseif rssi >= -50 then
		return 4
	elseif rssi >= -60 then
		return 3
	elseif rssi >= -70 then
		return 2
	else
		return 1
	end
end

wifi:subscribe("wifi_signal_update", function(env)
	local rssi = tonumber(env.rssi) or 0
	last_ssid = env.ssid or ""
	local bars = signal_bars(rssi)
	local connected = bars > 0

	local color
	if not connected then
		color = colors.with_alpha(colors.text, 0.3)
	elseif bars <= 1 then
		color = colors.red
	elseif bars == 2 then
		color = colors.orange
	else
		color = colors.with_alpha(colors.text, 0.7)
	end

	-- Map RSSI to a 0-100% quality figure (linear over -100..-50 dBm).
	local pct = math.max(0, math.min(100, 2 * (rssi + 100)))

	wifi:set({
		icon = {
			string = connected and icons.wifi.signal["_" .. bars] or icons.wifi.disconnected,
			color = color,
		},
		label = {
			drawing = connected,
			string = pct .. "%",
		},
	})
	-- Accent the signal value by strength: weak = red/orange, strong = green.
	local sig_color = style.value_color
	if not connected then
		sig_color = colors.with_alpha(colors.text, 0.4)
	elseif bars <= 1 then
		sig_color = colors.red
	elseif bars == 2 then
		sig_color = colors.orange
	elseif bars == 3 then
		sig_color = colors.yellow
	else
		sig_color = colors.green
	end
	signal_row:set({
		label = { string = connected and (rssi .. " dBm") or "off", color = sig_color },
	})
end)

local function hide_details()
	wifi_bracket:set({ popup = { drawing = false } })
end
local hide = popup_manager.register(hide_details)

local function toggle_details()
	local should_draw = wifi_bracket:query().popup.drawing == "off"
	if should_draw then
		popup_manager.close_others(hide)
		wifi_bracket:set({ popup = { drawing = true } })
		sbar.exec("networksetup -getcomputername", function(result)
			hostname:set({ label = result })
		end)
		sbar.exec("ipconfig getifaddr " .. net_iface, function(result)
			ip:set({ label = result })
		end)
		if last_ssid ~= "" then
			ssid:set({ label = last_ssid })
		else
			sbar.exec(
				"ipconfig getsummary " .. net_iface .. " | awk -F ' SSID : '  '/ SSID : / {print $2}'",
				function(result)
					-- macOS 15+ prints the literal "<redacted>" without location permission
					if result == "" or result:find("redacted") then
						result = "Wi-Fi"
					end
					ssid:set({ label = result })
				end
			)
		end
		sbar.exec("networksetup -getinfo Wi-Fi | awk -F 'Subnet mask: ' '/^Subnet mask: / {print $2}'", function(result)
			mask:set({ label = result })
		end)
		sbar.exec("networksetup -getinfo Wi-Fi | awk -F 'Router: ' '/^Router: / {print $2}'", function(result)
			router:set({ label = result })
		end)
	else
		hide_details()
	end
end

wifi_up:subscribe("mouse.clicked", toggle_details)
wifi_down:subscribe("mouse.clicked", toggle_details)
wifi:subscribe("mouse.clicked", toggle_details)
wifi:subscribe("mouse.exited.global", hide_details)

local function copy_label_to_clipboard(env)
	local label = sbar.query(env.NAME).label.value
	sbar.exec("echo \"" .. label .. "\" | pbcopy")
	sbar.set(env.NAME, { label = { string = icons.clipboard, align = "center" } })
	sbar.delay(1, function()
		sbar.set(env.NAME, { label = { string = label, align = "right" } })
	end)
end

ssid:subscribe("mouse.clicked", copy_label_to_clipboard)
hostname:subscribe("mouse.clicked", copy_label_to_clipboard)
ip:subscribe("mouse.clicked", copy_label_to_clipboard)
mask:subscribe("mouse.clicked", copy_label_to_clipboard)
router:subscribe("mouse.clicked", copy_label_to_clipboard)
