return {
  {
    "neovim/nvim-lspconfig",
    opts = function()
      -- Configure vim.diagnostic
      vim.diagnostic.config({
        -- Virtual text configuration (traditional inline diagnostics)
        virtual_text = {
          enabled = true,
          source = "if_many", -- Show source if multiple sources
          spacing = 4,
          prefix = "●", -- Could be '●', '▎', 'x', '■', etc.
        },

        -- Virtual lines configuration (diagnostics on separate lines)
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
          source = "always",
          prefix = "",
          scope = "cursor",
        },
      })

      -- Custom diagnostic signs
      local signs = {
        Error = " ",
        Warn = " ",
        Hint = " ",
        Info = " ",
      }

      for type, icon in pairs(signs) do
        local hl = "DiagnosticSign" .. type
        vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
      end

      -- Keymaps for diagnostics
      vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Open diagnostic float" })
      vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Go to previous diagnostic" })
      vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Go to next diagnostic" })
      vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Set diagnostic loclist" })

      -- Toggle virtual lines
      vim.keymap.set("n", "<leader>tv", function()
        local config = vim.diagnostic.config()
        if config.virtual_lines then
          vim.diagnostic.config({ virtual_lines = false })
          print("Virtual lines disabled")
        else
          vim.diagnostic.config({ virtual_lines = { only_current_line = false } })
          print("Virtual lines enabled")
        end
      end, { desc = "Toggle virtual lines" })

      -- Toggle virtual text
      vim.keymap.set("n", "<leader>tt", function()
        local config = vim.diagnostic.config()
        if config.virtual_text then
          vim.diagnostic.config({ virtual_text = false })
          print("Virtual text disabled")
        else
          vim.diagnostic.config({
            virtual_text = {
              source = "if_many",
              spacing = 4,
              prefix = "●",
            },
          })
          print("Virtual text enabled")
        end
      end, { desc = "Toggle virtual text" })
    end,
  },

  -- Optional: Enhanced diagnostics with virtual lines plugin
  {
    "https://git.sr.ht/~whynothugo/lsp_lines.nvim",
    config = function()
      require("lsp_lines").setup()

      -- Disable virtual_text since lsp_lines replaces it
      vim.diagnostic.config({
        virtual_text = false,
      })

      -- Toggle lsp_lines
      vim.keymap.set("n", "<leader>tl", require("lsp_lines").toggle, { desc = "Toggle lsp_lines" })
    end,
  },
}
