-- bufferline — WebStorm-style editor tabs
return {
  "akinsho/bufferline.nvim",
  lazy = false,
  init = function() require("utils.tab_drag").setup() end,
  keys = {
    { "<S-h>", "<cmd>BufferLineCyclePrev<CR>", desc = "Previous buffer" },
    { "<S-l>", "<cmd>BufferLineCycleNext<CR>", desc = "Next buffer" },
    { "<leader>bp", "<cmd>BufferLineTogglePin<CR>", desc = "Pin/unpin buffer" },
    { "<leader>bP", "<cmd>BufferLinePick<CR>", desc = "Pick buffer" },
  },
  opts = {
    options = {
      mode = "buffers",
      left_mouse_command = function(bufnr) require("utils.tab_drag").press(bufnr) end,
      show_buffer_icons = true,
      show_close_icon = false,
      buffer_close_icon = "x",
      modified_icon = "+",
      diagnostics = "nvim_lsp",
      always_show_bufferline = true,
      show_buffer_close_icons = true,
      separator_style = "thin",
      offsets = {
        {
          filetype = "neo-tree",
          text = "  Explorer",
          highlight = "Directory",
          text_align = "left",
        },
      },
    },
  },
}
