local function is_dark_mode()
  -- Query the *effective* appearance via a Swift helper that wraps
  -- NSApplication.effectiveAppearance. This works in Auto mode, where
  -- `defaults read -g AppleInterfaceStyle` returns empty even when the
  -- system is currently displaying dark. The helper is compiled by
  -- helpers/appearance_mode/makefile, which is invoked automatically
  -- from helpers/init.lua on every sketchybar config load.
  local bin = os.getenv("HOME") .. "/.config/sketchybar/helpers/appearance_mode/bin/appearance-mode"
  local handle = io.popen(bin .. " 2>/dev/null")
  if not handle then return false end
  local result = handle:read("*a")
  handle:close()
  return result:match("dark") ~= nil
end

if is_dark_mode() then
  return require("colors_dark")
else
  return require("colors_light")
end
