local wezterm = require("wezterm")

local config = {}

if wezterm.config_builder then
	config = wezterm.config_builder()
end

config.window_padding = {
	left = 5,
	right = 5,
	bottom = 0,
	top = 0,
}
config.window_decotrations = "NONE"
config.font = wezterm.font("JetBrainsMono Nerd Font")
config.font_size = 20
config.color_scheme = "Catppuccin Mocha"

return config
