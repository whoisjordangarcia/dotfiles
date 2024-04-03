local wezterm = require("wezterm")

local config = {}

config.wsl_domains = {
	name = "WSL:Ubuntu",
	distributions = "Ubuntu",
}

config.default_domain = "WSL:Ubuntu"

if wezterm.config_builder then
	config = wezterm.config_builder()
end

config.color_scheme = "Catppuccin Mocha"

return config
