local colors = require("colors")
local settings = require("settings")

local docker = sbar.add("item", "docker", {
	position = "right",
	icon = {
		string = "󰡨",
		font = {
			family = settings.font.text,
			size = 11.0,
		},
		color = colors.blue,
		padding_right = 4,
	},
	label = {
		font = {
			family = settings.font.numbers,
			size = 11.0,
		},
		color = colors.subtext,
	},
	background = { drawing = false },
	update_freq = 10,
	padding_left = 4,
	padding_right = 4,
	drawing = false,
})

local cmd = "/usr/local/bin/docker ps -q 2>/dev/null | wc -l | tr -d ' '"

docker:subscribe({ "routine", "forced" }, function()
	sbar.exec("pgrep -x Docker", function(pid)
		if not pid or pid == "" or pid == "\n" then
			docker:set({ drawing = false })
			return
		end
		sbar.exec(cmd, function(result)
			if not result or result == "" or result == "\n" then
				docker:set({ drawing = false })
				return
			end
			local count = tonumber(result:match("%d+"))
			if not count or count == 0 then
				docker:set({ drawing = false })
				return
			end
			docker:set({
				drawing = true,
				icon = { color = colors.green },
				label = { string = count .. " up" },
			})
		end)
	end)
end)

docker:subscribe("mouse.clicked", function()
	sbar.exec("open -a 'Docker Desktop'")
end)

sbar.add("item", { position = "right", width = 4 })
