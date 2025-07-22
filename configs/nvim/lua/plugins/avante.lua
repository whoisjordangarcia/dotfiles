-- https://github.com/yetone/avante.nvim
return {
  "yetone/avante.nvim",
  event = "VeryLazy",
  lazy = false,
  version = false, -- set this to "*" if you want to always pull the latest change, false to update on release
  branch = "main",
  opts = {
    -- work
    provider = "copilotgptfourone",
    auto_suggestions_provider = "copilotgptfourone",
    -- personal
    --provider = "lmstudio",
    --auto_suggestions_provider = "lmstudio",
    -- provider = "openrouter",
    -- auto_suggestions_provider = nil,
    providers = {
      -- work
      copilotsonnetfour = {
        __inherited_from = "copilot",
        model = "claude-sonnet-4",
      },
      copilotopus = {
        __inherited_from = "copilot",
        model = "claude-opus-4",
        extra_request_body = {
          timeout = 30000,
          temperature = 0,
        },
      },
      copilotclaude = {
        __inherited_from = "copilot",
        model = "claude-3.5-sonnet",
        extra_request_body = {
          timeout = 30000,
          temperature = 0,
          max_tokens = 16000,
        },
      },
      copilotclaudethreeseven = {
        __inherited_from = "copilot",
        model = "claude-3.7-sonnet",
      },
      copilotgptfourone = {
        __inherited_from = "copilot",
        model = "gpt-4.1",
      },

      -- personal
      openrouter = {
        __inherited_from = "openai",
        endpoint = "https://openrouter.ai/api/v1",
        model = "google/gemini-2.0-flash-001",
        extra_request_body = {
          temperature = 0,
          max_tokens = 16000,
        },
      },
      -- lmstudio = {
      --   __inherited_from = "openai",
      --   ["local"] = true,
      --   endpoint = "http://localhost:1234/v1",
      --   extra_request_body = {
      --     temperature = 0,
      --     max_tokens = 16000,
      --   },
      --
      --   --endpoint = "http://192.168.1.39:1234/v1",
      --   --model = "deepseek-coder-v2:16b",
      --   --model = "phi4:latest",
      --   --model = "llama3.3:latest",
      --   --model = "qwen2.5:32b", -- issues
      --   --model = 'hhao/qwen2.5-coder-tools:32b',
      --   --model = "nezahatkorkmaz/deepseek-v3:latest",
      --   --model = "DeepSeek-Coder-V2-Lite-Instruct-GGUF",
      --   --model = "DeepSeek-R1-Distill-Qwen-14B-GGUF",
      --   --model = "unsloth/deepseek-r1-distill-qwen-14b", -- great for architect mode
      --   --model = "qwen2.5-coder-14b-instruct", -- very fast
      --   model = "unsloth/deepseek-r1-distill-qwen-14b",
      --   -- parse_curl_args = function(opts, code_opts)
      --   --   return {
      --   --     url = opts.endpoint .. "/chat/completions",
      --   --     headers = {
      --   --       ["Accept"] = "application/json",
      --   --       ["Content-Type"] = "application/json",
      --   --       ["x-api-key"] = "lmstudio",
      --   --     },
      --   --     body = {
      --   --       model = opts.model,
      --   --       messages = require("avante.providers").copilot.parse_messages(code_opts), -- you can make your own message, but this is very advanced
      --   --       max_tokens = 6000,
      --   --       stream = true,
      --   --     },
      --   --   }
      --   -- end,
      --   --parse_response_data = function(data_stream, event_state, opts)
      --   --require("avante.providers").openai.parse_response(data_stream, event_state, opts)
      --   --end,
      -- },
      -- ollama = {
      --   ["local"] = true,
      --   endpoint = "http://localhost:11434/v1",
      --   --model = "deepseek-coder-v2:16b",
      --   --model = "phi4:latest",
      --   --model = "llama3.3:latest",
      --   --model = "qwen2.5:32b", -- issues
      --   --model = 'hhao/qwen2.5-coder-tools:32b',
      --   --model = "nezahatkorkmaz/deepseek-v3:latest",
      --   model = "hhao/qwen2.5-coder-tools:32b",
      --   parse_curl_args = function(opts, code_opts)
      --     return {
      --       url = opts.endpoint .. "/chat/completions",
      --       headers = {
      --         ["Accept"] = "application/json",
      --         ["Content-Type"] = "application/json",
      --         ["x-api-key"] = "ollama",
      --       },
      --       body = {
      --         model = opts.model,
      --         messages = require("avante.providers").copilot.parse_messages(code_opts), -- you can make your own message, but this is very advanced
      --         max_tokens = 8000,
      --         stream = true,
      --       },
      --     }
      --   end,
      --   parse_response_data = function(data_stream, event_state, opts)
      --     require("avante.providers").openai.parse_response(data_stream, event_state, opts)
      --   end,
      -- },
    },
    -- windows = {
    --   sidebar_header = { enabled = false },
    -- },
  },
  -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
  build = "make",
  -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "stevearc/dressing.nvim",
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    --- The below dependencies are optional,
    "echasnovski/mini.pick", -- for file_selector provider mini.pick
    --"nvim-telescope/telescope.nvim", -- for file_selector provider telescope
    "hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
    "ibhagwan/fzf-lua", -- for file_selector provider fzf
    "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
    "zbirenbaum/copilot.lua", -- for providers='copilot'
    -- {
    --   -- support for image pasting
    --   "HakonHarnes/img-clip.nvim",
    --   event = "VeryLazy",
    --   opts = {
    --     -- recommended settings
    --     default = {
    --       embed_image_as_base64 = false,
    --       prompt_for_file_name = false,
    --       drag_and_drop = {
    --         insert_mode = true,
    --       },
    --       -- required for Windows users
    --       use_absolute_path = true,
    --     },
    --   },
    -- },
    {
      -- Make sure to set this up properly if you have lazy=true
      "MeanderingProgrammer/render-markdown.nvim",
      opts = {
        file_types = { "markdown", "Avante" },
      },
      ft = { "markdown", "Avante" },
    },
    {
      "folke/which-key.nvim",
      optional = true,
      opts = {
        spec = {
          { "<leader>a", group = "ai" },
        },
      },
    },
  },
}
