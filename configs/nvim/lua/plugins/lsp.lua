return {
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed, {
        "tailwindcss-language-server",
        "typescript-language-server",
        "css-lsp",
        "pyright",
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        eslint = {},
        tsserver = {
          keys = {
            { "<leader>co", "<cmd>TypescriptOrganizeImports<CR>", desc = "Organize Imports" },
            { "<leader>cR", "<cmd>TypescriptRenameFile<CR>", desc = "Rename File" },
          },
        },
        basedpyright = require("lsp.basedpyright"),
        pyright = {
          enabled = false,
          settings = {
            python = {
              analysis = {
                autoSearchPaths = true,
                autoImportCompletions = true,
                useLibraryCodeForTypes = true,
                typeCheckingMode = "basic", -- ["off", "basic", "strict"]
                diagnosticMode = "openFilesOnly", -- ["openFilesOnly", "workspace"]
                diagnosticSeverityOverrides = {
                  -- https://microsoft.github.io/pyright/#/configuration?id=type-check-diagnostics-settings
                  reportDuplicateImport = "warning",
                  reportMissingTypeStubs = "warning",
                  -- slows down type analysis
                  -- reportImportCycles = "warning",
                  reportUnusedImport = "warning",
                  reportUnusedClass = "warning",
                  reportUnusedFunction = "warning",
                  reportUnusedVariable = "warning",
                },
              },
              -- reqrepo development
              -- we use pyrightconfig.json for the root directory now
              -- pythonPath = (function()
              --   if vim.fn.executable("pyenv") == 1 then
              --     return vim.fn.system(
              --       "echo -n `pyenv which python`:/Users/jordan.garcia/dev/invitae-web-core/lib/reqrepo:$PYTHONPATH"
              --     )
              --   else
              --     return vim.fn.system(
              --       "echo -n `which python`:/Users/jordan.garcia/dev/invitae-web-core/lib/reqrepo:$PYTHONPATH"
              --     )
              --   end
              -- end)(),
              --
              --venvPath = "/Users/jordan.garcia/.pyenv/versions",
              -- venv = "3.9.18",
              --
              --pythonPath = vim.fn.system("poetry env info --path"):gsub("%s+", "") .. "/bin/python",
              -- pythonPath = (function()
              --   if vim.fn.executable("pyenv") == 1 then
              --     return vim.fn.system("echo -n `pyenv which python`")
              --   else
              --     return vim.fn.system("echo -n `which python`")
              --   end
              -- end)(),
              -- venvPath = "",
            },
          },
        },
      },
      setup = {
        eslint = function()
          require("lazyvim.util").lsp.on_attach(function(client)
            if client.name == "eslint" then
              client.server_capabilities.documentFormattingProvider = true
            elseif client.name == "tsserver" then
              client.server_capabilities.documentFormattingProvider = false
            end
          end)
        end,
      },
    },
  },
}
