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

      -- JSON LSP: auto-discover project *.schema.json files from cwd at startup
      -- (works with git worktrees since cwd reflects the worktree path)
      local extra_schemas = {}
      local cwd = vim.fn.getcwd()
      -- Use system find with -prune to skip node_modules entirely (not just filter results)
      local schema_files = vim.fn.systemlist(
        "find " .. vim.fn.shellescape(cwd)
          .. " -path '*/node_modules' -prune"
          .. " -o -path '*/.git' -prune"
          .. " -o -path '*/__generated__' -prune"
          .. " -o -path '*/@generated' -prune"
          .. " -o -path '*/.worktrees' -prune"
          .. " -o -path '*/.nx' -prune"
          .. " -o -name '*.schema.json' -print"
          .. " 2>/dev/null"
      )
      for _, schema_path in ipairs(schema_files) do
        local filename = schema_path:match("([^/]+)%.schema%.json$")
        if filename then
          table.insert(extra_schemas, {
            description = filename:gsub("^%l", string.upper) .. " JSON schema",
            fileMatch = { "*." .. filename .. ".json" },
            name = filename .. ".json",
            url = "file://" .. schema_path,
          })
        end
      end

      opts.servers.jsonls = {
        settings = {
          json = {
            schemas = require("schemastore").json.schemas({ extra = extra_schemas }),
            validate = { enable = true },
          },
        },
      }

      return opts
    end,
  },
}
