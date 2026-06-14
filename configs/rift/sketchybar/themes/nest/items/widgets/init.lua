-- Load each widget in isolation. SbarLua hot-reloads on file save, so an
-- in-flight edit can be caught mid-state and throw during load. A bare
-- require() would abort the whole chain, leaving event providers firing
-- triggers into a bar with no handlers (the "wedged bar" failure mode).
-- pcall traps the error, logs it to sketchybar.err.log, and keeps loading
-- the rest so one broken widget never takes down the others.
local widgets = {
	"items.widgets.battery",
	"items.widgets.wifi",
	"items.widgets.brightness",
	"items.widgets.volume",
	"items.widgets.temp",
	"items.widgets.memory",
	"items.widgets.cpu",
}

for _, mod in ipairs(widgets) do
	local ok, err = pcall(require, mod)
	if not ok then
		io.stderr:write("sketchybar: widget '" .. mod .. "' failed to load: " .. tostring(err) .. "\n")
	end
end
