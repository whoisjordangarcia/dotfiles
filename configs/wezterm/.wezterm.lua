local wezterm = require("wezterm")

local config = {}

if wezterm.config_builder then
	config = wezterm.config_builder()
end

config.window_padding = {
	left = 5,
	right = 5,
	bottom = 0,
	top = 10,
}
config.window_decorations = "NONE"
config.font = wezterm.font("JetBrainsMono Nerd Font")
config.font_size = 20
config.color_scheme = "Catppuccin Mocha"
config.window_background_opacity = 0.9
config.show_tabs_in_tab_bar = false
config.show_new_tab_button_in_tab_bar = false
config.enable_tab_bar = false
return config
