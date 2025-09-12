return {
  {
    "epwalsh/obsidian.nvim",
    version = "*",
    lazy = true,
    ft = "markdown",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require("obsidian").setup({
        workspaces = {
          {
            name = "notes",
            path = "~/dev/notes",
          },
        },
        notes_subdir = "02 - Code",
        daily_notes = {
          folder = "03 - Daily Notes",
          date_format = "%Y-%m-%d",
          alias_format = "%B %-d, %Y",
        },
        completion = {
          nvim_cmp = true,
          min_chars = 2,
        },
        mappings = {
          ["gf"] = {
            action = function()
              return require("obsidian").util.gf_passthrough()
            end,
            opts = { noremap = false, expr = true, buffer = true },
          },
          ["<leader>ch"] = {
            action = function()
              return require("obsidian").util.toggle_checkbox()
            end,
            opts = { buffer = true },
          },
        },
      })
    end,
  },
}
