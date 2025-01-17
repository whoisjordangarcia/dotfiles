if true then
  return {}
end

return {
  "ibhagwan/fzf-lua",
  opts = function(_, opts)
    opts.winopts = {
      preview = {
        vertical = "up:65%",
        layout = "vertical",
      },
    }
  end,
}
