-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Highlight on search, but clear on pressing <Esc> in normal mode
vim.opt.hlsearch = true
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Exit terminal mode
--vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- TIP: Disable arrow keys in normal mode
vim.keymap.set("n", "<left>", '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set("n", "<right>", '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set("n", "<up>", '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set("n", "<down>", '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

-- CodeCompanion
-- vim.keymap.set({ "n", "v" }, "<C-a>", "<cmd>CodeCompanionActions<cr>", { noremap = true, silent = true })
-- vim.keymap.set(
--   { "n", "v" },
--   "<LocalLeader>aa",
--   "<cmd>CodeCompanionChat Toggle<cr>",
--   { noremap = true, silent = true, desc = "CodeCompanion" }
-- )
-- vim.keymap.set("v", "ga", "<cmd>CodeCompanionChat Add<cr>", { noremap = true, silent = true })
--
-- vim.keymap.set("n", "<LocalLeader>a/", function()
--   require("codecompanion").prompt("docs")
-- end, { noremap = true, silent = true, desc = "CodeCompanion Docs" })
--
-- -- Expand 'cc' into 'CodeCompanion' in the command line
-- vim.cmd([[cab cc CodeCompanion]])

-- NX commands for nearest project (finds project.json)
local function get_nx_project()
  local project_json = vim.fs.find("project.json", {
    upward = true,
    path = vim.fn.expand("%:p:h"),
  })[1]

  if project_json then
    local content = vim.fn.readfile(project_json)
    local json = vim.fn.json_decode(table.concat(content, "\n"))
    return json.name
  end
  return nil
end

vim.keymap.set("n", "<leader>cN", function()
  local project = get_nx_project()
  if project then
    vim.cmd("term nx lint " .. project)
  else
    vim.notify("No NX project found", vim.log.levels.WARN)
  end
end, { desc = "NX lint (nearest)" })

vim.keymap.set("n", "<leader>cB", function()
  local project = get_nx_project()
  if project then
    vim.cmd("term nx build " .. project)
  else
    vim.notify("No NX project found", vim.log.levels.WARN)
  end
end, { desc = "NX build (nearest)" })

vim.keymap.set("n", "<leader>cR", function()
  local project = get_nx_project()
  if project then
    vim.cmd("term nx run " .. project .. ":")
    vim.api.nvim_feedkeys("i", "n", false) -- Enter insert mode to type target
  else
    vim.notify("No NX project found", vim.log.levels.WARN)
  end
end, { desc = "NX run (nearest)" })

vim.keymap.set("n", "<leader>cC", function()
  local project = get_nx_project()
  local project_json = vim.fs.find("project.json", {
    upward = true,
    path = vim.fn.expand("%:p:h"),
  })[1]

  if project and project_json then
    local dir = vim.fn.fnamemodify(project_json, ":h")
    vim.cmd("term cd " .. dir .. " && npx tsc --noEmit && nx lint " .. project)
  else
    vim.notify("No NX project found", vim.log.levels.WARN)
  end
end, { desc = "NX check (types + lint)" })
