-- Require the sketchybar module
sbar = require("sketchybar")

-- Set the bar name, if you are using another bar instance than sketchybar
-- sbar.set_bar_name("bottom_bar")

-- Bundle the entire initial configuration into a single message to sketchybar
sbar.begin_config()

-- Define custom events used by workspace items (must exist before requiring items)
sbar.add("event", "aerospace_workspace_change")
sbar.add("event", "aerospace_focus_change")

require("bar")
require("default")
require("items")

-- Launch a lightweight background poller that bridges Aerospace state changes
-- into the custom SketchyBar events above. This avoids heavy per-second updates
-- by only triggering when something actually changes.
-- You can tune the poll interval by exporting AEROSPACE_POLL_INTERVAL (default 1s).
sbar.exec("pkill -f aerospace_events.sh >/dev/null 2>&1; $CONFIG_DIR/helpers/event_providers/aerospace_events.sh &")

sbar.end_config()

-- Run the event loop of the sketchybar module (without this there will be no
-- callback functions executed in the lua module)
sbar.event_loop()
