-- Dashboard with context-aware ASCII art headers
local function get_header()
  local cwd = vim.fn.getcwd()
  local home = vim.fn.expand("~")

  -- Work projects header
  if cwd:match(home .. "/projects") then
    return [[
                                    ░██
                                    ░██
░████████   ░███████   ░███████  ░████████
░██    ░██ ░██    ░██ ░██           ░██
░██    ░██ ░█████████  ░███████     ░██
░██    ░██ ░██               ░██    ░██
░██    ░██  ░███████   ░███████      ░████

                  g  e  n  o  m  i  c  s
]]
  end

  -- Default Neovim header for other locations
  return [[
       ████ ██████           █████      ██
      ███████████             █████
      █████████ ███████████████████ ███   ███████████
     █████████  ███    █████████████ █████ ██████████████
    █████████ ██████████ █████████ █████ █████ ████ █████
  ███████████ ███    ███ █████████ █████ █████ ████ █████
 ██████  █████████████████████ ████ █████ █████ ████ ██████
]]
end

-- Random dev quotes
local quotes = {
  "The best error message is the one that never shows up. — Thomas Fuchs",
  "First, solve the problem. Then, write the code. — John Johnson",
  "Code is like humor. When you have to explain it, it's bad. — Cory House",
  "Simplicity is the soul of efficiency. — Austin Freeman",
  "Make it work, make it right, make it fast. — Kent Beck",
  "Any fool can write code that a computer can understand. — Martin Fowler",
  "The only way to go fast, is to go well. — Robert C. Martin",
  "Deleted code is debugged code. — Jeff Sickel",
  "It works on my machine. — Every Developer",
  "There are only two hard things: cache invalidation and naming things. — Phil Karlton",
}

-- Get git info as a string
local function get_git_info()
  local branch = vim.fn.system("git branch --show-current 2>/dev/null"):gsub("\n", "")
  if branch == "" then
    return ""
  end

  local status = vim.fn.system("git status --porcelain 2>/dev/null")
  local modified = select(2, status:gsub("\n", "\n"))
  local icon = modified > 0 and "  " .. modified .. " changed" or "  clean"

  return "  " .. branch .. icon
end

-- Get recent commits as a string
local function get_recent_commits()
  local commits = vim.fn.system("git log --oneline -3 2>/dev/null")
  if commits == "" or commits:match("^fatal") then
    return ""
  end

  local lines = { "  Recent Commits" }
  for line in commits:gmatch("[^\n]+") do
    local hash, msg = line:match("^(%w+)%s+(.+)$")
    if hash and msg then
      if #msg > 45 then
        msg = msg:sub(1, 42) .. "..."
      end
      table.insert(lines, "  " .. hash:sub(1, 7) .. " " .. msg)
    end
  end

  return table.concat(lines, "\n")
end

-- Get a random quote
local function get_random_quote()
  math.randomseed(os.time())
  return "  " .. quotes[math.random(#quotes)]
end

return {
  {
    "folke/snacks.nvim",
    opts = function()
      return {
        -- Disable features that conflict with Telescope
        scroll = { enabled = false },
        picker = { enabled = false },
        explorer = { enabled = false },
        -- Enable just the dashboard
        dashboard = {
          preset = {
            header = get_header(),
          },
          sections = {
            { section = "header" },
            { section = "keys", gap = 1, padding = 1 },
            { text = get_git_info(), align = "center", padding = 1 },
            { text = get_random_quote(), align = "center", hl = "Comment", padding = 1 },
            { section = "startup" },
          },
        },
      }
    end,
  },
}
