return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "bash",
        "html",
        "javascript",
        "json",
        "lua",
        "markdown",
        "python",
        "regex",
        "tsx",
        "typescript",
        "vim",
        "yaml",
        "go",
        "gitignore",
        "css",
        "http",
        "sql",
      },
    },
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

