-- Coordinates all bar popups so only one is open at a time.
-- Each popup registers its bracket + a hide() callback; before a popup opens
-- it calls close_others() to dismiss any other open popup.
local M = { entries = {} }

-- hide: function that closes this popup. Returns the same hide fn for chaining.
function M.register(hide)
	table.insert(M.entries, hide)
	return hide
end

-- Close every registered popup except the one whose hide fn is `keep`.
function M.close_others(keep)
	for _, hide in ipairs(M.entries) do
		if hide ~= keep then
			hide()
		end
	end
end

return M
