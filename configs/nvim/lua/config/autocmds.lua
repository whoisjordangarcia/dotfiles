-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Softer diff highlights
local function set_diff_highlights()
  vim.api.nvim_set_hl(0, "DiffAdd", { bg = "#1e3a2e" })
  vim.api.nvim_set_hl(0, "DiffDelete", { bg = "#3a1e2e" })
  vim.api.nvim_set_hl(0, "DiffChange", { bg = "#1e2e3a" })
  vim.api.nvim_set_hl(0, "DiffText", { bg = "#2e4a5a" })
end

set_diff_highlights()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_diff_highlights })

-- Diff mode: line numbers only on the right (new) panel, clean gutters on both
vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
  callback = function()
    if not vim.wo.diff then
      return
    end

    vim.wo.signcolumn = "no"
    vim.wo.foldcolumn = "0"

    local wins = vim.api.nvim_tabpage_list_wins(0)
    local diff_wins = {}
    for _, w in ipairs(wins) do
      if vim.wo[w].diff then
        table.insert(diff_wins, { win = w, col = vim.api.nvim_win_get_position(w)[2] })
      end
    end

    if #diff_wins >= 2 then
      table.sort(diff_wins, function(a, b)
        return a.col < b.col
      end)
      local current = vim.api.nvim_get_current_win()
      if current == diff_wins[1].win then
        vim.wo.number = false
      else
        vim.wo.number = true
      end
      vim.wo.relativenumber = false
    end
  end,
})
