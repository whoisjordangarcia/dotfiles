-- Load each widget in isolation. SbarLua hot-reloads on file save, so an
-- in-flight edit can be caught mid-state and throw during load. A bare
-- require() would abort the whole chain, leaving event providers firing
-- triggers into a bar with no handlers (the "wedged bar" failure mode).
-- pcall traps the error, logs it to sketchybar.err.log, and keeps loading
-- the rest so one broken widget never takes down the others.
-- Right-positioned widgets lay out right-to-left in load order, so this list
-- reads as the reverse of what you see in the bar.
local widgets = {
	"items.widgets.battery",
	"items.widgets.wifi",
	"items.widgets.brightness",
	"items.widgets.volume",
	"items.widgets.temp",
	"items.widgets.memory",
	"items.widgets.cpu",
	"items.widgets.claude",
}

for _, mod in ipairs(widgets) do
	local ok, err = pcall(require, mod)
	if not ok then
		io.stderr:write("sketchybar: widget '" .. mod .. "' failed to load: " .. tostring(err) .. "\n")
	end
end

-- On the notch, since this looks like it wants "fixing":
--
-- `position` has no notch awareness -- it packs leftward from the screen edge
-- regardless -- so on the built-in panel a wide enough right cluster slides its
-- leftmost widgets under the notch. That is a function of *logical resolution*,
-- not of the widget set: widths are in points and don't scale, but the screen
-- does. At 1512pt the cluster clears the notch by ~80pt; at 1147pt ("Larger
-- Text") it loses ~365pt of bar and cpu/memory/temp disappear underneath it.
--
-- If that comes back, resist the two obvious fixes. sketchybar's notch-relative
-- anchors ("q"/"e") do dodge it, but they collapse to the screen *centre* on
-- displays without a notch, stranding these widgets mid-bar with a gap before
-- the rest of the cluster. And a global "is the built-in active" switch can't
-- help either, since position is per-item, not per-display -- with the lid open
-- it dodges on every screen at once. Genuinely fixing it per-display means two
-- copies of each widget behind `display=` filters (which does accept a list),
-- popups and subscriptions included. Raising the resolution is cheaper.
