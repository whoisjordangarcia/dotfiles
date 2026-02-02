-- Customize lualine statusline (overrides LazyVim defaults)
return {
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
    -- Custom branch component with truncation
    local function truncated_branch()
      local branch = vim.b.gitsigns_head or ""
      if branch == "" then
        return ""
      end

      local max_len = 30 -- Maximum branch name length

      if #branch <= max_len then
        return branch
      end

      -- For branches like "jordan/NES-3217-additional-updates-to-patient-list"
      -- Try to preserve the prefix and ticket number
      local prefix, rest = branch:match("^([^/]+/[A-Z]+-[0-9]+)%-(.+)$")
      if prefix then
        local remaining = max_len - #prefix - 1 -- -1 for the dash
        if remaining > 3 then
          return prefix .. "-" .. rest:sub(1, remaining - 2) .. "…"
        else
          return prefix .. "…"
        end
      end

      -- Fallback: simple truncation
      return branch:sub(1, max_len - 1) .. "…"
    end

    -- Find and replace the branch component in lualine_b
    if opts.sections and opts.sections.lualine_b then
      for i, component in ipairs(opts.sections.lualine_b) do
        if component == "branch" or (type(component) == "table" and component[1] == "branch") then
          opts.sections.lualine_b[i] = {
            truncated_branch,
            icon = "", -- git branch icon
          }
          break
        end
      end
    end

    return opts
  end,
}
