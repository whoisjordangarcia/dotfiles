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
}
