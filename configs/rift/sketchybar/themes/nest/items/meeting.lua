local colors = require("colors")
local settings = require("settings")

local meeting = sbar.add("item", "meeting", {
	position = "right",
	icon = {
		string = "MTG",
		font = {
			family = settings.font.text,
			size = 11.0,
		},
		color = colors.teal,
		padding_right = 4,
	},
	label = {
		font = {
			family = settings.font.text,
			size = 11.0,
		},
		color = colors.subtext,
		max_chars = 30,
	},
	background = { drawing = false },
	update_freq = 30,
	padding_left = 4,
	padding_right = 4,
	drawing = false,
})

-- AppleScript to get next calendar event
local get_next = [[osascript -e '
set now to current date
set endOfDay to now + (24 * 60 * 60)
try
  tell application "Calendar"
    set nearest to endOfDay
    set nearestTitle to ""
    repeat with c in calendars
      set evts to (every event of c whose start date >= now and start date < endOfDay)
      repeat with e in evts
        set s to start date of e
        if s < nearest and s >= now then
          set nearest to s
          set nearestTitle to summary of e
        end if
      end repeat
    end repeat
    if nearestTitle is not "" then
      set diff to (nearest - now) / 60
      set diff to round diff rounding down
      if diff < 60 then
        return nearestTitle & " in " & diff & "m"
      else
        set hrs to diff div 60
        set mins to diff mod 60
        return nearestTitle & " in " & hrs & "h" & mins & "m"
      end if
    end if
  end tell
end try
return ""
']]

meeting:subscribe({ "routine", "forced", "system_woke" }, function()
	sbar.exec(get_next, function(result)
		if not result or result == "" or result == "\n" then
			meeting:set({ drawing = false })
			return
		end
		result = result:match("^%s*(.-)%s*$")
		if result == "" then
			meeting:set({ drawing = false })
			return
		end

		-- Color based on urgency
		local color = colors.subtext
		if result:find("in %d+m") then
			local mins = tonumber(result:match("in (%d+)m"))
			if mins and mins <= 5 then
				color = colors.red
			elseif mins and mins <= 15 then
				color = colors.yellow
			end
		end

		meeting:set({
			drawing = true,
			label = { string = result, color = color },
		})
	end)
end)

meeting:subscribe("mouse.clicked", function()
	sbar.exec("open -a Fantastical")
end)

sbar.add("item", { position = "right", width = 4 })
