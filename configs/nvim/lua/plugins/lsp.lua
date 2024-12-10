return {
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed, {
        --"tailwindcss-language-server",
        "typescript-language-server",
        --"css-lsp",
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        eslint = {},
        pyright = {
          enabled = true,
          settings = {
            python = {
              analysis = {
                autoSearchPaths = true,
                autoImportCompletions = true,
                useLibraryCodeForTypes = true,
                typeCheckingMode = "basic", -- ["off", "basic", "strict"]
                diagnosticMode = "openFilesOnly", -- ["openFilesOnly", "workspace"]
                diagnosticSeverityOverrides = {
                  reportDuplicateImport = "warning",
                  reportImportCycles = "warning",
                  reportMissingImports = "error",
                  reportMissingModuleSource = "error",
                },
              },
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
              -- venvPath = "/Users/jordan.garcia/.pyenv/versions",
              -- venv = "3.8.18",
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
