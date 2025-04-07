if true then
  return {}
end

return {
  {
    "chipsenkbeil/org-roam.nvim",
    tag = "0.1.1",
    dependencies = {
      {
        "nvim-orgmode/orgmode",
        tag = "0.3.7",
      },
    },
    config = function()
      require("orgmode").setup({
        org_agenda_files = { "~/notes/**/*" },
        org_default_notes_file = "~/notes/refile.org",
      })

      require("org-roam").setup({
        directory = "~/notes",
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {},
    config = function(_, opts)
      -- Load the default Treesitter configuration
      require("nvim-treesitter.configs").setup(opts)

      -- Add custom parser for org files
      local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
      parser_config.org = {
        install_info = {
          url = "https://github.com/milisims/tree-sitter-org",
          revision = "main",
          files = { "src/parser.c", "src/scanner.c" },
        },
        filetype = "org",
      }
    end,
  },
}
