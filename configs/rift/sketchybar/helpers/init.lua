-- from https://github.com/FelixKratz/dotfiles
-- or curl -L https://raw.githubusercontent.com/FelixKratz/dotfiles/master/install_sketchybar.sh | sh
-- Add the sketchybar module to the package cpath
package.cpath = package.cpath .. ";" .. os.getenv("HOME") .. "/.local/share/sketchybar_lua/?.so"

-- Add active theme to package path so require("bar"), require("items"), etc.
-- resolve to the theme's files first. themes/active is a machine-local
-- symlink (gitignored, managed by switch-theme.sh) — fall back to the nest
-- theme so a fresh clone works before any theme has been selected.
local config_dir = os.getenv("CONFIG_DIR") or (os.getenv("HOME") .. "/.config/sketchybar")
local theme_path = config_dir .. "/themes/active"
if not os.execute('test -e "' .. theme_path .. '"') then
	theme_path = config_dir .. "/themes/nest"
end
package.path = theme_path .. "/?.lua;" .. theme_path .. "/?/init.lua;" .. package.path

os.execute("(cd helpers && make)")
