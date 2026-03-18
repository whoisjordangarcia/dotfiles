return {
  {
    "pwntester/octo.nvim",
    cmd = "Octo",
    keys = {
      -- PR browsing
      { "<leader>gpl", "<cmd>Octo pr list<cr>", desc = "PR list" },
      { "<leader>gpc", "<cmd>Octo pr checks<cr>", desc = "PR checks" },
      { "<leader>gpb", "<cmd>Octo pr browser<cr>", desc = "Open PR in browser" },
      {
        "<leader>gpo",
        function()
          local trim = function(s) return s:gsub("%s+$", "") end
          local pr = trim(vim.fn.system("gh pr view --json number -q .number 2>/dev/null"))
          if pr ~= "" and pr:match("^%d+$") then
            vim.cmd("Octo pr edit " .. pr)
          else
            vim.notify("No PR found for current branch", vim.log.levels.WARN)
          end
        end,
        desc = "Open current branch PR",
      },
      -- Review workflow
      {
        "<leader>gpr",
        function()
          local trim = function(s) return s:gsub("%s+$", "") end
          local pr = trim(vim.fn.system("gh pr view --json number -q .number 2>/dev/null"))
          if pr ~= "" and pr:match("^%d+$") then
            vim.cmd("Octo pr edit " .. pr)
            vim.defer_fn(function()
              vim.cmd("Octo review start")
            end, 1500)
          else
            vim.notify("No PR found for current branch", vim.log.levels.WARN)
          end
        end,
        desc = "Start PR review (with comments)",
      },
    },
    opts = {},
  },
}
