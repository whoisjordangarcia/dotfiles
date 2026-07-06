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

      -- Base jsonls config: SchemaStore's catalog is available immediately.
      opts.servers.jsonls = {
        settings = {
          json = {
            schemas = require("schemastore").json.schemas(),
            validate = { enable = true },
          },
        },
      }

      -- JSON LSP: auto-discover project *.schema.json files under cwd and merge
      -- them into the running jsonls client. This runs ASYNCHRONOUSLY (off the
      -- UI thread) and only once jsonls actually attaches (i.e. you opened a
      -- JSON file). Previously this shelled out to a synchronous `find` over the
      -- entire cwd inside opts(), which froze Neovim on startup in large trees
      -- (e.g. $HOME or the monorepo) — see git history / debugging notes.
      local function discover_schemas_async()
        local cwd = vim.fn.getcwd()
        -- -prune skips heavy dirs entirely instead of just filtering results.
        local cmd = {
          "find", cwd,
          "-path", "*/node_modules", "-prune",
          "-o", "-path", "*/.git", "-prune",
          "-o", "-path", "*/__generated__", "-prune",
          "-o", "-path", "*/@generated", "-prune",
          "-o", "-path", "*/.worktrees", "-prune",
          "-o", "-path", "*/.nx", "-prune",
          "-o", "-name", "*.schema.json", "-print",
        }
        -- 5s cap: if the tree is enormous we degrade gracefully to whatever was
        -- found so far rather than blocking anything.
        vim.system(cmd, { text = true, timeout = 5000 }, function(res)
          local out = res.stdout or ""
          if out == "" then
            return
          end
          local extra_schemas = {}
          for schema_path in out:gmatch("[^\n]+") do
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
          if #extra_schemas == 0 then
            return
          end
          -- Back on the main loop: push the merged schema set to jsonls.
          vim.schedule(function()
            local ok, schemastore = pcall(require, "schemastore")
            if not ok then
              return
            end
            local schemas = schemastore.json.schemas({ extra = extra_schemas })
            for _, client in ipairs(vim.lsp.get_clients({ name = "jsonls" })) do
              client.settings = vim.tbl_deep_extend("force", client.settings or {}, {
                json = { schemas = schemas },
              })
              client.notify("workspace/didChangeConfiguration", { settings = client.settings })
            end
          end)
        end)
      end

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("jsonls_schema_discovery", { clear = true }),
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client.name == "jsonls" and not vim.g._jsonls_schemas_discovered then
            vim.g._jsonls_schemas_discovered = true
            discover_schemas_async()
          end
        end,
      })

      return opts
    end,
  },
}
