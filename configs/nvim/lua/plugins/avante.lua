-- https://github.com/yetone/avante.nvim
return {
  "yetone/avante.nvim",
  event = "VeryLazy",
  lazy = false,
  version = false, -- set this to "*" if you want to always pull the latest change, false to update on release
  opts = {
    -- add any opts here
    --provider = "openai",
    -- work
    -- copilot = {
    --   endpoint = "https://api.githubcopilot.com",
    --   model = "claude-3.5-sonnet",
    --   proxy = nil, -- [protocol://]host[:port] Use this proxy
    --   allow_insecure = false, -- Allow insecure server connections
    --   timeout = 30000, -- Timeout in milliseconds
    --   temperature = 0,
    --   max_tokens = 4096,
    -- },
    -- provider = "copilot",

    provider = "copilotclaude",
    auto_suggestions_provider = "copilotclaude",
    vendors = {
      copilotclaude = {
        __inherited_from = "copilot",
        model = "claude-3.5-sonnet",
        timeout = 30000,
        temperature = 0,
        max_tokens = 4096,
      },
    },
  },
  -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
  build = "make",
  -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
  dependencies = {
    "stevearc/dressing.nvim",
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    --- The below dependencies are optional,
    "hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
    "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
    "zbirenbaum/copilot.lua", -- for providers='copilot'
    {
      -- support for image pasting
      "HakonHarnes/img-clip.nvim",
      event = "VeryLazy",
      opts = {
        -- recommended settings
        default = {
          embed_image_as_base64 = false,
          prompt_for_file_name = false,
          drag_and_drop = {
            insert_mode = true,
          },
          -- required for Windows users
          use_absolute_path = true,
        },
      },
    },
    {
      -- Make sure to set this up properly if you have lazy=true
      "MeanderingProgrammer/render-markdown.nvim",
      opts = {
        file_types = { "markdown", "Avante" },
      },
      ft = { "markdown", "Avante" },
    },
  },
}