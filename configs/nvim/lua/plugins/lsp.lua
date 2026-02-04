return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      -- TypeScript LSP optimizations for large monorepos
      opts.servers.ts_ls = {
        init_options = {
          maxTsServerMemory = 16384,
          disableAutomaticTypingAcquisition = true,
        },
        settings = {
          typescript = {
            preferences = {
              includePackageJsonAutoImports = "off",
            },
            suggest = {
              autoImports = true,
              includeCompletionsForModuleExports = true,
            },
            tsserver = {
              experimental = {
                enableProjectDiagnostics = false,
              },
            },
          },
          javascript = {
            preferences = {
              includePackageJsonAutoImports = "off",
            },
          },
        },
      }

      -- JSON LSP with SchemaStore + custom schemas
      opts.servers.jsonls = {
        settings = {
          json = {
            schemas = require("schemastore").json.schemas({
              extra = {
                {
                  description = "Story JSON schema for patient-navigator",
                  fileMatch = { "*.story.json" },
                  name = "story.json",
                  url = "file:///Users/nest/projects/nest/apps/frontend/patient-navigator/src/schemas/story.schema.json",
                },
              },
            }),
            validate = { enable = true },
          },
        },
      }

      return opts
    end,
  },
}
