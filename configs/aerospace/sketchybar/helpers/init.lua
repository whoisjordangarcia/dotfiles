-- from https://github.com/FelixKratz/dotfiles
-- or curl -L https://raw.githubusercontent.com/FelixKratz/dotfiles/master/install_sketchybar.sh | sh
-- Add the sketchybar module to the package cpath
package.cpath = package.cpath .. ";/Users/" .. os.getenv("USER") .. "/.local/share/sketchybar_lua/?.so"

-- Add active theme to package path so require("bar"), require("items"), etc.
-- resolve to the theme's files first
local config_dir = os.getenv("CONFIG_DIR") or (os.getenv("HOME") .. "/.config/sketchybar")
local theme_path = config_dir .. "/themes/active"
package.path = theme_path .. "/?.lua;" .. theme_path .. "/?/init.lua;" .. package.path

os.execute("(cd helpers && make)")
