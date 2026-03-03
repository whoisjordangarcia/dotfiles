local colors = require("colors")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

local max_workspaces = 10
local query_workspaces = "rift-cli query workspaces"

local workspaces = {}
local last_focused = nil

-- Generation counter per workspace: prevents stale async callbacks from rendering
local update_gen = {}
for i = 1, max_workspaces do update_gen[i] = 0 end

local function updateWindows(workspace_index)
	local rift_ws_index = workspace_index - 1

	-- Bump generation so any in-flight query for this workspace is invalidated
	update_gen[workspace_index] = update_gen[workspace_index] + 1
	local my_gen = update_gen[workspace_index]

	sbar.exec(query_workspaces, function(all_workspaces)
		-- If a newer updateWindows was called for this workspace, discard this result
		if update_gen[workspace_index] ~= my_gen then return end
		if not all_workspaces then return end

		local focused_index = nil
		local windows = {}

		for _, ws in ipairs(all_workspaces) do
			if ws.is_active then
				focused_index = ws.index
			end
			if ws.index == rift_ws_index then
				windows = ws.windows or {}
			end
		end

		local icon_line = ""
		local no_app = (#windows == 0)

		for _, win in ipairs(windows) do
			local app = win.app_name
			local lookup = app_icons[app]
			local icon = ((lookup == nil) and app_icons["Default"] or lookup)
			icon_line = icon_line .. " " .. icon
		end

		local is_focused = (focused_index == rift_ws_index)

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
		local focused_index = tonumber(focused_name)
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

		-- Update windows for both the newly focused workspace and the one that lost focus
		-- (updateWindows branches on is_focused, so both need a refresh)
		if is_focused then
			-- Update the previously focused workspace (it may need to hide/change)
			if last_focused and last_focused ~= workspace_index then
				updateWindows(last_focused)
			end
			last_focused = workspace_index
			updateWindows(workspace_index)
		end
	end)

	workspace:subscribe("rift_windows_changed", function(env)
		-- Only update the workspace that actually changed
		local changed_name = env.RIFT_WORKSPACE_NAME
		if changed_name == tostring(workspace_index) then
			updateWindows(workspace_index)
		end
	end)

	workspace:subscribe("display_change", function()
		updateWindows(workspace_index)
	end)

	updateWindows(workspace_index)
	sbar.exec(query_workspaces, function(all_workspaces)
		if not all_workspaces then return end
		for _, ws in ipairs(all_workspaces) do
			if ws.is_active and ws.name == tostring(workspace_index) then
				workspaces[workspace_index]:set({
					icon = { highlight = true },
					label = { highlight = true },
					background = {
						color = colors.with_alpha(colors.white, 0.15),
					},
				})
			end
		end
	end)
end
