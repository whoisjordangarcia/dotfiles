local function is_dark_mode()
  local handle = io.popen("defaults read -g AppleInterfaceStyle 2>/dev/null")
  if not handle then return false end
  local result = handle:read("*a")
  handle:close()
  return result:match("Dark") ~= nil
end

if is_dark_mode() then
  return require("colors_dark")
else
  return require("colors_light")
end
