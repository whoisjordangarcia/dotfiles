-- Require the sketchybar module
sbar = require("sketchybar")

-- Set the bar name, if you are using another bar instance than sketchybar
-- sbar.set_bar_name("bottom_bar")

-- Bundle the entire initial configuration into a single message to sketchybar
sbar.begin_config()

-- Define custom events for rift window manager integration
sbar.add("event", "rift_workspace_changed")
sbar.add("event", "rift_windows_changed")
sbar.add("event", "workspace_app_change")

require("bar")
require("default")
require("items")

-- No polling needed: rift pushes events via rift-cli subscribe in config.toml run_on_start

sbar.end_config()

-- Trigger initial workspace update after config is applied
sbar.exec("rift-cli query workspaces | jq -r '.[] | select(.is_active) | .name'", function(name)
	if name then
		name = name:match("^%s*(.-)%s*$") or ""
		sbar.trigger("rift_workspace_changed", { RIFT_WORKSPACE_NAME = name })
	end
end)
sbar.trigger("rift_windows_changed")

-- Run the event loop of the sketchybar module (without this there will be no
-- callback functions executed in the lua module)
sbar.event_loop()
