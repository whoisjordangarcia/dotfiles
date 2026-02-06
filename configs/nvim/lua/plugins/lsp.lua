return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      -- Enable oxlint LSP for fast JS/TS linting
      opts.servers.oxlint = {}

      -- Disable ts_ls (using vtsls instead)
      opts.servers.ts_ls = { enabled = false }

      -- TypeScript LSP (vtsls) optimizations for large monorepos
      opts.servers.vtsls = {
        settings = {
          typescript = {
            tsserver = {
              maxTsServerMemory = 4096,
              experimental = {
                enableProjectDiagnostics = false,
              },
            },
            preferences = {
              includePackageJsonAutoImports = "off",
            },
            suggest = {
              autoImports = true,
              includeCompletionsForModuleExports = true,
            },
          },
          javascript = {
            preferences = {
              includePackageJsonAutoImports = "off",
            },
          },
          vtsls = {
            autoUseWorkspaceTsdk = true,
            enableMoveToFileCodeAction = true,
            experimental = {
              completion = {
                enableServerSideFuzzyMatch = true,
              },
              -- Use nearest tsconfig for each file (better monorepo support)
              maxInlayHintLength = 30,
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
