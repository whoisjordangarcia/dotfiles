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

-- Run a git command with a HARD timeout. `vim.system():wait(ms)` kills the
-- process if it overruns, so a slow/huge repo (e.g. a large monorepo where
-- `git status` takes seconds) can never block/freeze the dashboard.
local function git(args, timeout_ms)
  local cmd = { "git" }
  vim.list_extend(cmd, args)
  local ok, res = pcall(function()
    return vim.system(cmd, { text = true }):wait(timeout_ms or 400)
  end)
  if not ok or not res or res.code ~= 0 then
    return ""
  end
  return (res.stdout or ""):gsub("%s+$", "")
end

-- Get git info as a string
local function get_git_info()
  local branch = git({ "branch", "--show-current" })
  if branch == "" then
    return ""
  end

  local status = git({ "status", "--porcelain" })
  local modified = 0
  for _ in status:gmatch("[^\r\n]+") do
    modified = modified + 1
  end
  local icon = modified > 0 and "  " .. modified .. " changed" or "  clean"

  return "  " .. branch .. icon
end

-- Get recent commits as a string
local function get_recent_commits()
  local commits = git({ "log", "--oneline", "-3" })
  if commits == "" then
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
    keys = {
      { "<leader>gD", false }, -- disable Snacks git_diff, diffview owns this key
    },
    opts = function()
      return {
        scroll = { enabled = false },
        picker = {
          sources = {
            files = {
              hidden = true,
              args = { "--exclude", ".git", "--exclude", "node_modules", "--exclude", ".nx", "--exclude", ".next" },
            },
            grep = {
              hidden = true,
              args = { "--hidden", "-g", "!.git", "-g", "!node_modules", "-g", "!.nx", "-g", "!.next" },
            },
          },
        },
        explorer = { enabled = false },
        -- Enable just the dashboard
        dashboard = {
          preset = {
            header = get_header(),
          },
          sections = {
            { section = "header" },
            { section = "keys", gap = 1, padding = 1 },
            -- Wrapped in functions so the git calls run only when the dashboard
            -- actually renders (i.e. bare `nvim`) — never on `nvim .`/file opens
            -- and never during startup config evaluation.
            function()
              return { text = get_git_info(), align = "center", padding = 1 }
            end,
            function()
              return { text = get_random_quote(), align = "center", hl = "Comment", padding = 1 }
            end,
            { section = "startup" },
          },
        },
      }
    end,
  },
}
