local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

local media_back = sbar.add("item", "media.back", {
	position = "left",
	icon = {
		string = icons.media.back,
		font = {
			family = settings.font.text,
			size = 12.0,
		},
		color = colors.grey,
		padding_right = 0,
	},
	label = { drawing = false },
	background = { drawing = false },
	drawing = false,
	padding_left = 4,
	padding_right = 0,
})

local media_play = sbar.add("item", "media.play", {
	position = "left",
	icon = {
		string = icons.media.play_pause,
		font = {
			family = settings.font.text,
			size = 14.0,
		},
		color = colors.green,
		padding_right = 0,
	},
	label = { drawing = false },
	background = { drawing = false },
	drawing = false,
	padding_left = 2,
	padding_right = 2,
})

local media_forward = sbar.add("item", "media.forward", {
	position = "left",
	icon = {
		string = icons.media.forward,
		font = {
			family = settings.font.text,
			size = 12.0,
		},
		color = colors.grey,
		padding_right = 4,
	},
	label = { drawing = false },
	background = { drawing = false },
	drawing = false,
	padding_left = 0,
	padding_right = 2,
})

local media = sbar.add("item", "media", {
	position = "left",
	icon = { drawing = false },
	label = {
		font = {
			family = settings.font.text,
			size = 11.0,
		},
		color = colors.subtext,
		max_chars = 40,
	},
	background = { drawing = false },
	drawing = false,
	updates = true,
	update_freq = 5,
	padding_left = 0,
	padding_right = 4,
})

local spotify_cmd = 'osascript -e "try" -e "tell application \\"Spotify\\"" -e "set s to player state as string" -e "set t to name of current track" -e "set a to artist of current track" -e "return s & \\"||\\" & t & \\" - \\" & a" -e "end tell" -e "end try" -e "return \\"\\""'

local function set_drawing(visible)
	media:set({ drawing = visible })
	media_back:set({ drawing = visible })
	media_play:set({ drawing = visible })
	media_forward:set({ drawing = visible })
end

local function update_media(state, track_info)
	if not track_info or track_info == "" then
		set_drawing(false)
		return
	end
	local is_playing = (state == "playing")
	local play_color = is_playing and colors.green or colors.yellow
	set_drawing(true)
	media_play:set({
		icon = { color = play_color },
	})
	media:set({
		label = { string = track_info },
	})
end

media:subscribe("media_change", function(env)
	if env.INFO.app == "Spotify" then
		update_media(env.INFO.state, env.INFO.title .. " - " .. env.INFO.artist)
	end
end)

media:subscribe({ "routine", "forced" }, function()
	sbar.exec(spotify_cmd, function(result)
		if not result or result == "" or result == "\n" then
			set_drawing(false)
			return
		end
		result = result:match("^%s*(.-)%s*$")
		if result == "" then
			set_drawing(false)
			return
		end
		local state, track_info = result:match("^(.-)%|%|(.+)$")
		if state and track_info then
			update_media(state, track_info)
		end
	end)
end)

media_back:subscribe("mouse.clicked", function()
	sbar.exec('osascript -e "tell application \\"Spotify\\" to previous track"')
end)

media_play:subscribe("mouse.clicked", function()
	sbar.exec('osascript -e "tell application \\"Spotify\\" to playpause"')
end)

media_forward:subscribe("mouse.clicked", function()
	sbar.exec('osascript -e "tell application \\"Spotify\\" to next track"')
end)

media:subscribe("mouse.clicked", function()
	sbar.exec('osascript -e "tell application \\"Spotify\\" to playpause"')
end)
