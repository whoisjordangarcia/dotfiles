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

        virtual_lines = false, -- Disable virtual lines completely

        -- Custom signs for different severity levels
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "✗",
            [vim.diagnostic.severity.WARN] = "⚠",
            [vim.diagnostic.severity.INFO] = "ℹ",
            [vim.diagnostic.severity.HINT] = "💡",
          },
        },

        -- Underline errors/warnings
        underline = true,

        -- Update diagnostics in insert mode
        update_in_insert = false,

        -- Severity sorting (errors first, then warnings, etc.)
        severity_sort = true,

        -- Float window configuration for hover diagnostics
        -- float = {
        --   focusable = false,
        --   close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
        --   border = "rounded",
        --   source = "if_many",
        --   prefix = "",
        --   scope = "cursor",
        --   max_width = 100, -- Prevent overly wide float windows
        --   max_height = 20, -- Prevent overly tall float windows
        --   header = "", -- Remove default header
        -- },
      })
    end,
  },
}
