-- if true then
--   return {}
-- end
--
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        pyright = {
          enabled = true,
          settings = {
            python = {
              analysis = {
                autoSearchPaths = true,
                autoImportCompletions = true,
                useLibraryCodeForTypes = true,
                -- typeCheckingMode = "basic", -- ["off", "basic", "strict"]
                -- diagnosticMode = "workspace", -- ["openFilesOnly", "workspace"]
                -- diagnosticSeverityOverrides = {
                --   reportDuplicateImport = "warning",
                --   reportImportCycles = "warning",
                --   reportMissingImports = "error",
                --   reportMissingModuleSource = "error",
                -- },
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
    },
  },
}
