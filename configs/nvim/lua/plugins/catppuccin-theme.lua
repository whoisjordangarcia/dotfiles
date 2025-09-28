return {
  {
    "catppuccin/nvim",
    lazy = false,
    name = "catppuccin",
    -- you can do it like this with a config function
    config = function()
      require("catppuccin").setup({
        transparent_background = true,
        custom_highlights = function(colors)
          return {
            LineNr = { fg = colors.yellow },
            CursorLineNr = { fg = colors.lavender, style = { "bold" } },
            TabLineSel = { bg = colors.pink },
            CursorLine = { bg = colors.crust },
          }
        end,
      })
    end,
    enable = false,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
