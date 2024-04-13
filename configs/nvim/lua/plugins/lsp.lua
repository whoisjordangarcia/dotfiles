return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      pyright = {
        enabled = true,
        settings = {
          python = {
            pythonPath = (function()
              if vim.fn.executable("pyenv") == 1 then
                return vim.fn.system(
                  "echo -n `pyenv which python`:/Users/jordan.garcia/dev/invitae-web-core/lib/reqrepo:$PYTHONPATH"
                )
              else
                return vim.fn.system(
                  "echo -n `which python`:/Users/jordan.garcia/dev/invitae-web-core/lib/reqrepo:$PYTHONPATH"
                )
              end
            end)(),
            venvPath = "/Users/jordan.garcia/.pyenv/versions",
            venv = "3.8.18",
          },
        },
      },
    },
  },
}
