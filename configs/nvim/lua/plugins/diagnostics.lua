return {
  {
    "neovim/nvim-lspconfig",
    opts = function()
      vim.diagnostic.config({
        virtual_text = {
          enabled = true,
          source = "if_many", -- Show source if multiple sources
          spacing = 4,
          prefix = "●", -- Could be '●', '▎', 'x', '■', etc.
        },

        virtual_lines = {
          enabled = true,
          only_current_line = false, -- Show for all lines or just current
        },

        -- Signs in the gutter
        signs = true,

        -- Underline errors/warnings
        underline = true,

        -- Update diagnostics in insert mode
        update_in_insert = false,

        -- Severity sorting (errors first, then warnings, etc.)
        severity_sort = true,

        -- Float window configuration for hover diagnostics
        float = {
          focusable = false,
          close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
          border = "rounded",
          source = "if_many",
          prefix = "",
          scope = "cursor",
        },
      })
    end,
  },
}
