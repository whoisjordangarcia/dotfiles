return {
  {
    "folke/trouble.nvim",
    opts = {
      auto_open = false,
      auto_preview = false,
      hooks = {
        after_open = function(bufnr)
          vim.api.nvim_buf_call(bufnr, function()
            vim.opt_local.wrap = true
          end)
        end,
      },
    },
  },
}
