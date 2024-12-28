local wezterm = require("wezterm")

local config = {}

if wezterm.config_builder then
	config = wezterm.config_builder()
end

config.window_padding = {
	left = 0,
	right = 0,
	bottom = 0,
	top = 0,
}

config.font = wezterm.font("JetBrainsMono Nerd Font")
config.font_size = 20

config.color_scheme = "Catppuccin Mocha"
config.window_background_opacity = 0.9
config.show_tabs_in_tab_bar = true
config.win32_system_backdrop = 'Acrylic'
config.show_new_tab_button_in_tab_bar = true
config.enable_tab_bar = true 
config.use_resize_increments = true
config.adjust_window_size_when_changing_font_size = false

config.default_domain ='WSL:Ubuntu-24.04'
return config
