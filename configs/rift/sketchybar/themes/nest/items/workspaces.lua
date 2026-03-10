local colors = require("colors")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

local max_workspaces = 10
local query_workspaces = "rift-cli query workspaces"

local workspaces = {}
local last_focused = nil

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

	local icon_line = ""
	local no_app = (#windows == 0)
	local is_focused = (focused_index == rift_ws_index)

	for _, win in ipairs(windows) do
		local app = win.app_name
		local lookup = app_icons[app]
		local icon = ((lookup == nil) and app_icons["Default"] or lookup)
		icon_line = icon_line .. " " .. icon
	end

	if is_focused then
		sbar.trigger("workspace_app_change", { HAS_APP = no_app and "false" or "true" })
	end

	-- No animation here — structural drawing changes must be instant
	-- to avoid overlapping animations from rapid event bursts
	if no_app and is_focused then
		workspaces[workspace_index]:set({
			icon = { drawing = true, padding_right = 8 },
			label = {
				string = "",
				drawing = false,
			},
			background = { drawing = true },
			padding_right = 1,
			padding_left = 1,
		})
	elseif no_app then
		workspaces[workspace_index]:set({
			icon = { drawing = false },
			label = { drawing = false },
			background = { drawing = false },
			padding_right = 0,
			padding_left = 0,
		})
	else
		workspaces[workspace_index]:set({
			icon = { drawing = true },
			label = { drawing = true, string = icon_line },
			background = { drawing = true },
			padding_right = 1,
			padding_left = 1,
		})
	end
end

-- Single query, distributes results to all workspaces
local function refreshAllWorkspaces()
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
	end)
end

for workspace_index = 1, max_workspaces do
	local rift_ws_index = workspace_index - 1

	local workspace = sbar.add("item", {
		icon = {
			color = colors.overlay,
			highlight_color = colors.text,
			drawing = false,
			font = { family = settings.font.numbers, size = 12.0 },
			string = workspace_index,
			padding_left = 8,
			padding_right = 4,
		},
		label = {
			padding_right = 8,
			color = colors.subtext,
			highlight_color = colors.text,
			font = "sketchybar-app-font:Regular:14.0",
			y_offset = -1,
		},
		padding_right = 1,
		padding_left = 1,
		background = {
			color = colors.surface0,
			corner_radius = 8,
			height = 24,
			border_width = 0,
		},
		click_script = "rift-cli execute workspace switch " .. rift_ws_index,
	})

	workspaces[workspace_index] = workspace

	workspace:subscribe("rift_workspace_changed", function(env)
		local focused_name = env.RIFT_WORKSPACE_NAME
		local is_focused = focused_name == tostring(workspace_index)

		sbar.animate("tanh", 10, function()
			workspace:set({
				icon = { highlight = is_focused },
				label = { highlight = is_focused },
				background = {
					color = is_focused and colors.surface1 or colors.surface0,
				},
			})
		end)

		-- Only the newly focused workspace triggers a full refresh
		-- (the refresh updates ALL workspaces, so old+new both get correct state)
		if is_focused then
			last_focused = workspace_index
			refreshAllWorkspaces()
		end
	end)

	workspace:subscribe("rift_windows_changed", function(env)
		-- Only workspace 1 triggers the refresh to avoid 10 simultaneous queries.
		-- The gen counter handles any remaining races from rapid events.
		if workspace_index == 1 then
			refreshAllWorkspaces()
		end
	end)

	workspace:subscribe("display_change", function()
		-- Only workspace 1 triggers the display-change handler
		-- The script debounces by pausing Rift's auto_assign_windows during
		-- macOS display negotiation, then re-enables it for a single clean re-tile
		if workspace_index == 1 then
			display_change_gen = display_change_gen + 1
			local my_gen = display_change_gen

			-- Fire the debounced display-change script (handles Rift auto-assign toggle)
			sbar.exec(os.getenv("HOME") .. "/dev/dotfiles/configs/rift/display-change.sh", function()
				if display_change_gen ~= my_gen then return end
				refreshAllWorkspaces()
			end)
		end
	end)
end

-- Initial load: single query to set up all workspaces
refreshAllWorkspaces()
sbar.exec(query_workspaces, function(all_workspaces)
	if not all_workspaces then return end
	for _, ws in ipairs(all_workspaces) do
		local ws_index = ws.index + 1
		if ws.is_active and ws_index >= 1 and ws_index <= max_workspaces then
			workspaces[ws_index]:set({
				icon = { highlight = true },
				label = { highlight = true },
				background = {
					color = colors.with_alpha(colors.white, 0.15),
				},
			})
		end
	end
end)
