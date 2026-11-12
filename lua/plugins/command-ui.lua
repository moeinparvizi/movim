return {
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
  opts = {
    cmdline = { enabled = true, view = "cmdline_popup" },
    messages = { enabled = false },
    popupmenu = { enabled = false },
    lsp = { progress = { enabled = false }, hover = { enabled = false }, signature = { enabled = false }, message = { enabled = false } },
    views = {
      cmdline_popup = {
        position = { row = "35%", col = "50%" },
        size = { width = 60, height = "auto" },
        border = { style = "rounded", padding = { 0, 1 } },
      },
    },
  },
}
