local colors = require("colors")
local settings = require("settings")
local scale = require("scale")

local max_workspaces = 10
local pill_height = 24
-- A workspace's windows draw as a strip of overlapping rounded tiles, each
-- with the app's real icon centred; helpers/app_strip renders the whole strip
-- as one image (one item per workspace keeps reloads fast). Sizes are in
-- unscaled bar px; the image is rendered at strip_unit px per bar px.
local tile_px = 20
local icon_px = 16
local overlap = 8
local tile_corner = 5
local strip_unit = 4
-- The focused window draws at full strength; every other window is dimmed.
local dim_alpha = 0.4
-- Active-workspace identifier: an accent border drawn around the focused
-- workspace (on top of the existing surface1 background + text highlight).
local active_border_width = 2
local active_border_color = colors.blue
-- `timeout` guards against a wedged rift daemon: an unresponsive socket would
-- otherwise leave every event-driven query hanging forever, piling up hundreds
-- of rift-cli processes. After 3s the query is killed instead of accumulating.
local query_workspaces =
	"if command -v timeout >/dev/null 2>&1; then timeout 3 rift-cli query workspaces; else gtimeout 3 rift-cli query workspaces; fi"

local refreshAllWorkspaces

-- Strips are cached by content (windows, focus, sizes, theme colours), so a
-- light/dark switch or a size change renders fresh files. Rendering is async:
-- until a strip exists the workspace keeps showing its previous one.
local strip_dir = os.getenv("HOME") .. "/.cache/sketchybar/workspace_strips"
local config_dir = os.getenv("CONFIG_DIR") or (os.getenv("HOME") .. "/.config/sketchybar")
os.execute('mkdir -p "' .. strip_dir .. '" && find "' .. strip_dir .. '" -name "*.png" -mtime +7 -delete')
local strip_requested = {}

local function hash(s)
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + s:byte(i)) % 4294967296
	end
	return string.format("%08x", h)
end

local function stripPath(windows)
	local entries = {}
	for _, win in ipairs(windows) do
		table.insert(entries, (win.bundle_id or "unknown") .. ":" .. (win.is_focused and "1" or "0"))
	end
	local args = {
		tile_px, icon_px, overlap, tile_corner, dim_alpha,
		string.format("%08x", colors.base), string.format("%08x", colors.surface2),
		-- A 1pt border on screen, in canvas px.
		strip_unit / scale.scale, strip_unit,
	}
	local arg_str = table.concat(args, " ") .. " " .. table.concat(entries, " ")
	local path = strip_dir .. "/" .. hash(arg_str) .. ".png"
	local f = io.open(path, "r")
	if f then
		f:close()
		return path
	end
	if not strip_requested[path] then
		strip_requested[path] = true
		sbar.exec(string.format('"%s/helpers/app_strip/bin/app_strip" "%s" %s', config_dir, path, arg_str), function()
			refreshAllWorkspaces()
		end)
	end
	return nil
end

local workspaces = {}
local was_visible = {}
local shown_strip = {}
local highlighted = nil
local indicator = nil
local indicator_placed = false

-- The focus ring is one item drawn over the pills that glides to the focused
-- pill. It sits after the last workspace and takes no layout space: padding
-- pulls it back over its target, and padding_left + width + padding_right
-- stays 0, also mid-animation since all three ease along the same curve.
-- Positions come from sketchybar's own layout, in drawn px, so they are
-- divided by scale before scale_props multiplies them back.
-- Uses item:query() rather than shelling out to `sketchybar --query`: the CLI
-- stalls against the config process while the bar is loading.
local function placeIndicator(workspace_index)
	local target = workspaces[workspace_index]:query()
	local ring = indicator:query()
	for display, rect in pairs(target.bounding_rects or {}) do
		local own = ring.bounding_rects and ring.bounding_rects[display]
		if rect.origin[1] > -9000 and own and own.origin[1] > -9000 then
			local natural_x = own.origin[1] - ring.geometry.padding_left
			local distance = (natural_x - rect.origin[1]) / scale.scale
			local width = rect.size[1] / scale.scale
			local props = {
				padding_left = -distance,
				width = width,
				padding_right = distance - width,
			}
			if indicator_placed then
				sbar.animate("tanh", 18, function()
					indicator:set(props)
				end)
			else
				props.background = { drawing = true }
				indicator:set(props)
				indicator_placed = true
			end
			return
		end
	end
end

local function setHighlight(workspace_index, is_focused)
	workspaces[workspace_index]:set({
		icon = { highlight = is_focused },
		background = { color = is_focused and colors.surface1 or colors.surface0 },
	})
end

-- Global generation counter: prevents stale async callbacks from rendering
-- when rapid events trigger multiple refreshAllWorkspaces() calls
local refresh_gen = 0
local display_change_gen = 0

local function applyWorkspaceState(workspace_index, ws_data, focused_index)
	local rift_ws_index = workspace_index - 1
	local windows = {}

	if ws_data then
		windows = ws_data.windows or {}
	end

	local no_app = (#windows == 0)
	local is_focused = (focused_index == rift_ws_index)

	if is_focused then
		sbar.trigger("workspace_app_change", { HAS_APP = no_app and "false" or "true" })
	end

	-- No animation here — structural drawing changes must be instant
	-- to avoid overlapping animations from rapid event bursts.
	-- Toggle the item, not its background: setHighlight sets background.color,
	-- which sketchybar treats as background.drawing = on.
	local visible = not no_app or is_focused
	local strip = not no_app and stripPath(windows) or nil
	if no_app then
		shown_strip[workspace_index] = nil
	end
	local props = {
		drawing = visible,
		icon = { padding_right = no_app and 8 or 7 },
		label = { drawing = not no_app },
	}
	if strip and strip ~= shown_strip[workspace_index] then
		shown_strip[workspace_index] = strip
		local width = tile_px + (tile_px - overlap) * (#windows - 1)
		props.label = {
			drawing = true,
			-- A background image draws from the label's left edge and ignores
			-- padding_right, so the pill's end padding is part of the width.
			width = width + 6,
			background = { image = { string = strip, scale = scale.scale / strip_unit } },
		}
	end
	workspaces[workspace_index]:set(props)

	-- A workspace that just appeared pops in: the pill grows to full height and
	-- its number rises. Not on the first refresh after load (was_visible still
	-- nil), which would animate every pill at once.
	if visible and was_visible[workspace_index] == false then
		workspaces[workspace_index]:set({ background = { height = pill_height / 2 }, icon = { y_offset = -3 } })
		sbar.animate("tanh", 15, function()
			workspaces[workspace_index]:set({ background = { height = pill_height }, icon = { y_offset = 0 } })
		end)
	end
	was_visible[workspace_index] = visible
end

-- Single query, distributes results to all workspaces
function refreshAllWorkspaces()
	refresh_gen = refresh_gen + 1
	local my_gen = refresh_gen

	sbar.exec(query_workspaces, function(all_workspaces)
		-- If a newer refresh was triggered, discard this result
		if refresh_gen ~= my_gen then return end
		if not all_workspaces then return end

		-- Build a lookup table: rift_index -> workspace data
		local ws_by_index = {}
		local focused_index = nil

		for _, ws in ipairs(all_workspaces) do
			ws_by_index[ws.index] = ws
			if ws.is_active then
				focused_index = ws.index
			end
		end

		-- Update all workspaces from cached query
		for i = 1, max_workspaces do
			local rift_ws_index = i - 1
			applyWorkspaceState(i, ws_by_index[rift_ws_index], focused_index)
		end

		-- Focus comes from rift's is_active here, not the switch event's name,
		-- which doesn't always match a pill and used to leave none highlighted.
		local focused = focused_index and focused_index + 1
		if focused ~= highlighted then
			local previous = highlighted
			highlighted = focused
			if previous == nil then
				for i = 1, max_workspaces do
					setHighlight(i, i == focused)
				end
			else
				sbar.animate("tanh", 10, function()
					setHighlight(previous, false)
					if focused then
						setHighlight(focused, true)
					end
				end)
			end
		end

		if focused_index then
			placeIndicator(focused_index + 1)
		end
	end)
end

for workspace_index = 1, max_workspaces do
	local rift_ws_index = workspace_index - 1

	local workspace = sbar.add("item", "workspace." .. workspace_index, {
		drawing = false,
		icon = {
			color = colors.overlay,
			highlight_color = colors.text,
			font = { family = settings.font.numbers, size = 12.0 },
			string = workspace_index,
			padding_left = 8,
			padding_right = 4,
		},
		label = {
			drawing = false,
			string = "",
			padding_left = 0,
			padding_right = 0,
			background = { drawing = true, color = colors.transparent },
		},
		padding_right = 1,
		padding_left = 1,
		background = {
			color = colors.surface0,
			corner_radius = 8,
			height = pill_height,
			border_width = 0,
		},
		click_script = "rift-cli execute workspace switch " .. rift_ws_index,
	})

	workspaces[workspace_index] = workspace

	workspace:subscribe("rift_workspace_changed", function(env)
		-- Only workspace 1 refreshes; the refresh updates every pill and the ring.
		if workspace_index == 1 then
			refreshAllWorkspaces()
		end
	end)

	-- front_app_switched: rift sends no event when focus moves within a workspace,
	-- and the dimmed/active icons follow the focused window.
	workspace:subscribe({ "rift_windows_changed", "front_app_switched" }, function(env)
		-- Only workspace 1 triggers the refresh to avoid 10 simultaneous queries.
		-- The gen counter handles any remaining races from rapid events.
		if workspace_index == 1 then
			refreshAllWorkspaces()
		end
	end)

	workspace:subscribe("display_change", function()
		-- Only workspace 1 triggers the display-change handler
		-- The script waits out macOS display negotiation, then reloads sketchybar if the displays changed
		if workspace_index == 1 then
			display_change_gen = display_change_gen + 1
			local my_gen = display_change_gen

			sbar.exec(os.getenv("HOME") .. "/dev/dotfiles/configs/rift/display-change.sh", function()
				if display_change_gen ~= my_gen then return end
				refreshAllWorkspaces()
			end)
		end
	end)
end

indicator = sbar.add("item", "workspace.indicator", {
	width = 0,
	padding_left = 0,
	padding_right = 0,
	icon = { drawing = false },
	label = { drawing = false },
	background = {
		drawing = false,
		color = colors.transparent,
		border_width = active_border_width,
		border_color = active_border_color,
		corner_radius = 8,
		height = pill_height,
	},
})

-- Initial load: single query to set up all workspaces
refreshAllWorkspaces()
