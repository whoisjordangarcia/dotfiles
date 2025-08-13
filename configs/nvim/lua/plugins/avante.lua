-- https://github.com/yetone/avante.nvim
return {
  "yetone/avante.nvim",
  build = "make",
  event = "VeryLazy",
  version = false, -- Never set this value to "*"! Never!
  opts = {
    mode = "agentic",

    -- work
    provider = "copilot",
    model = "claude-sonnet-4",

    -- OPTIONS
    -- claude-opus-4
    -- gpt-5.1

    -- personal
    -- provider = "openrouter",
    --
    providers = {
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
    },
    -- windows = {
    --   width = 30,
    --   input = {
    --     prefix = "> ",
    --     height = 10,
    --   },
    -- },

    input = {
      provider = "snacks",
      provider_opts = {
        -- Additional snacks.input options
        title = "Avante Input",
        icon = " ",
      },
    },

    selector = {
      --- @alias avante.SelectorProvider "native" | "fzf_lua" | "mini_pick" | "snacks" | "telescope" | fun(selector: avante.ui.Selector): nil
      --- @type avante.SelectorProvider
      provider = "snacks",
      -- Options override for custom providers
      provider_opts = {},
    },

    shortcuts = {
      {
        name = "refactor",
        description = "Refactor code with best practices",
        details = "Automatically refactor code to improve readability, maintainability, and follow best practices while preserving functionality",
        prompt = "Please refactor this code following best practices, improving readability and maintainability while preserving functionality.",
      },
      {
        name = "test",
        description = "Generate unit tests",
        details = "Create comprehensive unit tests covering edge cases, error scenarios, and various input conditions",
        prompt = "Please generate comprehensive unit tests for this code, covering edge cases and error scenarios.",
      },
    },
  },

  config = function(_, opts)
    require("avante").setup(opts)

    -- Helper to prefill edit window and auto-submit
    local function prefill_edit_window(request)
      require("avante.api").edit()
      local bufnr = vim.api.nvim_get_current_buf()
      local winid = vim.api.nvim_get_current_win()
      if not bufnr or not winid then
        return
      end
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { request })
      vim.api.nvim_win_set_cursor(winid, { 1, #request + 1 })
      local keys = vim.api.nvim_replace_termcodes("<C-s>", true, true, true)
      vim.api.nvim_feedkeys(keys, "v", true)
    end

    -- Prompt templates
    local avante_grammar_correction = "Correct the text to standard English, but keep any code blocks inside intact."
    local avante_keywords = "Extract the main keywords from the following text"
    local avante_code_readability_analysis = [[
You must identify any readability issues in the code snippet.
Some readability issues to consider:
- Unclear naming
- Unclear purpose
- Redundant or obvious comments
- Lack of comments
- Long or complex one liners
- Too much nesting
- Long variable names
- Inconsistent naming and code style.
- Code repetition
You may identify additional problems. The user submits a small section of code from a larger file.
Only list lines with readability issues, in the format <line_num>|<issue and proposed solution>
If there's no issues with code respond with only: <OK>
]]
    local avante_optimize_code = "Optimize the following code"
    local avante_summarize = "Summarize the following text"
    local avante_explain_code = "Explain the following code"

    -- Dynamically fetch filetype for completion prompts
    local function complete_code_prompt()
      return "Complete the following codes written in " .. vim.bo.filetype
    end

    local avante_add_docstring = "Add docstring to the following codes"
    local avante_fix_bugs = "Fix the bugs inside the following codes if any"
    local avante_add_tests = "Implement tests for the following code"

    -- Keymaps (using which-key if present)
    local wk_ok, wk = pcall(require, "which-key")
    if wk_ok then
      -- Ask mode
      wk.add({
        { "<leader>a", group = "Avante" },
        {
          mode = { "n", "v" },
          {
            "<leader>ag",
            function()
              require("avante.api").ask({ question = avante_grammar_correction })
            end,
            desc = " Grammar Correction(ask)",
          },
          {
            "<leader>ak",
            function()
              require("avante.api").ask({ question = avante_keywords })
            end,
            desc = " Keywords (ask)",
          },
          {
            "<leader>al",
            function()
              require("avante.api").ask({ question = avante_code_readability_analysis })
            end,
            desc = " Code Readability Analysis (ask)",
          },
          {
            "<leader>ao",
            function()
              require("avante.api").ask({ question = avante_optimize_code })
            end,
            desc = " Optimize Code (ask)",
          },
          {
            "<leader>am",
            function()
              require("avante.api").ask({ question = avante_summarize })
            end,
            desc = " Summarize text (ask)",
          },
          {
            "<leader>ax",
            function()
              require("avante.api").ask({ question = avante_explain_code })
            end,
            desc = " Explain Code (ask)",
          },
          {
            "<leader>aC",
            function()
              require("avante.api").ask({ question = complete_code_prompt() })
            end,
            desc = " Complete Code (ask)",
          },
          {
            "<leader>ad",
            function()
              require("avante.api").ask({ question = avante_add_docstring })
            end,
            desc = " Docstring (ask)",
          },
          {
            "<leader>ab",
            function()
              require("avante.api").ask({ question = avante_fix_bugs })
            end,
            desc = " Fix Bugs (ask)",
          },
          {
            "<leader>au",
            function()
              require("avante.api").ask({ question = avante_add_tests })
            end,
            desc = " Add Tests (ask)",
          },
        },
      })

      -- Edit mode
      wk.add({
        { "<leader>a", group = "Avante" },
        {
          mode = { "v" },
          {
            "<leader>aG",
            function()
              prefill_edit_window(avante_grammar_correction)
            end,
            desc = " Grammar Correction(edit)",
          },
          {
            "<leader>aK",
            function()
              prefill_edit_window(avante_keywords)
            end,
            desc = " Keywords(edit)",
          },
          {
            "<leader>aO",
            function()
              prefill_edit_window(avante_optimize_code)
            end,
            desc = " Optimize Code(edit)",
          },
          {
            "<leader>aC",
            function()
              prefill_edit_window(complete_code_prompt())
            end,
            desc = " Complete Code(edit)",
          },
          {
            "<leader>aD",
            function()
              prefill_edit_window(avante_add_docstring)
            end,
            desc = " Docstring(edit)",
          },
          {
            "<leader>aB",
            function()
              prefill_edit_window(avante_fix_bugs)
            end,
            desc = " Fix Bugs(edit)",
          },
          {
            "<leader>aU",
            function()
              prefill_edit_window(avante_add_tests)
            end,
            desc = " Add Tests(edit)",
          },
        },
      })
    end
  end,
  dependencies = {
    "stevearc/dressing.nvim", -- for input provider dressing
    "folke/snacks.nvim", -- for input provider snacks
    "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
    "zbirenbaum/copilot.lua", -- for providers='copilot'
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
