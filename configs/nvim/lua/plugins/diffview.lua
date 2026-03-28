return {
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diff view (working changes)" },
      {
        "<leader>gD",
        function()
          local function trim(s)
            return s:gsub("%s+$", "")
          end

          -- 1. Try upstream tracking branch, but only if it's a base branch (release/*, stg)
          local upstream = trim(vim.fn.system("git rev-parse --abbrev-ref @{upstream} 2>/dev/null"))
          if upstream ~= "" and not upstream:match("fatal") and (upstream:match("release/") or upstream:match("/stg$")) then
            vim.notify("Diffing against " .. upstream, vim.log.levels.INFO)
            vim.cmd("DiffviewOpen " .. upstream .. "...HEAD")
            return
          end

          -- 2. Find closest release branch by fewest commits ahead of merge-base
          local base = trim(vim.fn.system([[
            for ref in $(git branch -r --list 'origin/release/*' --sort=-version:refname | head -5 | tr -d ' '); do
              mb=$(git merge-base HEAD "$ref" 2>/dev/null)
              [ -n "$mb" ] && echo "$(git rev-list --count "$mb..HEAD") $ref"
            done | sort -n | head -1 | awk '{print $2}'
          ]]))

          if base ~= "" then
            vim.notify("Diffing against " .. base, vim.log.levels.INFO)
            vim.cmd("DiffviewOpen " .. base .. "...HEAD")
            return
          end

          -- 3. Fallback: prompt
          vim.ui.input({ prompt = "Base branch: " }, function(ref)
            if ref and ref ~= "" then
              vim.cmd("DiffviewOpen origin/" .. ref .. "...HEAD")
            end
          end)
        end,
        desc = "Diff view (branch vs base, like a PR)",
      },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File history (current file)" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "File history (repo)" },
      { "<leader>gq", "<cmd>DiffviewClose<cr>", desc = "Close diff view" },
    },
    opts = {
      view = {
        default = { layout = "diff2_horizontal" },
      },
      file_panel = {
        listing_style = "tree",
        width = 40,
      },
    },
  },
}
