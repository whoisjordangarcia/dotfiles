return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
      "nvim-neotest/nvim-nio",
      "williamboman/mason.nvim",
      "leoluz/nvim-dap-python",
    },
  },
  config = function()
    local dap = require("dap")
    local ui = require("dapui")

    require("dapui").setup()
    require("dap-go").setup()
  end,
}
