-- Same isolation as widgets/init.lua: load each top-level item group under
-- pcall so a single failing module logs and is skipped rather than aborting
-- the whole config load and wedging the bar.
local items = {
	"items.workspaces",
	"items.front_app",
	"items.calendar",
	-- "items.media",
	"items.widgets",
}

for _, mod in ipairs(items) do
	local ok, err = pcall(require, mod)
	if not ok then
		io.stderr:write("sketchybar: item '" .. mod .. "' failed to load: " .. tostring(err) .. "\n")
	end
end
