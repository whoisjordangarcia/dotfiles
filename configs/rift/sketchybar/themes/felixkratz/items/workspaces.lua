local colors = require("colors")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

local max_workspaces = 10

-- Query all rift workspaces (returns JSON array parsed by sbar.exec)
local query_workspaces = "rift-cli query workspaces"

sbar.add("item", {
	icon = {
		color = colors.with_alpha(colors.white, 0.3),
		highlight_color = colors.white,
		drawing = false,
	},
	label = {
		color = colors.grey,
		highlight_color = colors.white,
		drawing = false,
	},
	background = {
		color = colors.bg0,
		border_width = 1,
		height = 28,
		border_color = colors.black,
		corner_radius = 9,
		drawing = false,
	},
	padding_left = 6,
	padding_right = 0,
})

local workspaces = {}

local function updateWindows(workspace_index)
	local rift_ws_index = workspace_index - 1

	sbar.exec(query_workspaces, function(all_workspaces)
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

		sbar.animate("tanh", 10, function()
			if no_app and focused_index == rift_ws_index then
				workspaces[workspace_index]:set({
					icon = { drawing = true },
					label = {
						string = " —",
						drawing = true,
						font = "sketchybar-app-font:Regular:16.0",
						y_offset = -1,
					},
					background = { drawing = true },
					padding_right = 1,
					padding_left = 1,
				})
				return
			end

			if no_app then
				workspaces[workspace_index]:set({
					icon = { drawing = false },
					label = { drawing = false },
					background = { drawing = false },
					padding_right = 0,
					padding_left = 0,
				})
				return
			end

			workspaces[workspace_index]:set({
				icon = { drawing = true },
				label = { drawing = true, string = icon_line },
				background = { drawing = true },
				padding_right = 1,
				padding_left = 1,
			})
		end)
	end)
end

for workspace_index = 1, max_workspaces do
	local rift_ws_index = workspace_index - 1

	local workspace = sbar.add("item", {
		icon = {
			color = colors.with_alpha(colors.white, 0.3),
			highlight_color = colors.red,
			drawing = false,
			font = { family = settings.font.numbers },
			string = workspace_index,
			padding_left = 10,
			padding_right = 5,
		},
		label = {
			padding_right = 10,
			color = colors.grey,
			highlight_color = colors.white,
			font = "sketchybar-app-font:Regular:16.0",
			y_offset = -1,
		},
		padding_right = 2,
		padding_left = 2,
		background = {
			color = colors.bg2,
			border_width = 1,
			height = 28,
			border_color = colors.grey,
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
					border_width = is_focused and 2 or 1,
				},
				blur_radius = 30,
			})
		end)

		updateWindows(workspace_index)
	end)

	workspace:subscribe("rift_windows_changed", function()
		updateWindows(workspace_index)
	end)

	workspace:subscribe("display_change", function()
		updateWindows(workspace_index)
	end)

	-- Initial setup
	updateWindows(workspace_index)
	sbar.exec(query_workspaces, function(all_workspaces)
		if not all_workspaces then return end
		for _, ws in ipairs(all_workspaces) do
			if ws.is_active and ws.name == tostring(workspace_index) then
				workspaces[workspace_index]:set({
					icon = { highlight = true },
					label = { highlight = true },
					background = { border_width = 2 },
				})
			end
		end
	end)
end
