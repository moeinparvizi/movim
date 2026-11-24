-- aerial — the Structure tool window (file outline sidebar)
return {
  "stevearc/aerial.nvim",
  branch = "master",
  cmd = { "AerialToggle", "AerialNavOpen", "AerialInfo" },
  keys = {
    { "<leader>o", "<cmd>AerialToggle right<CR>", desc = "Toggle structure (outline)" },
    { "<leader>co", "<cmd>AerialNavOpen<CR>", desc = "Structure navigator" },
  },
  opts = {
    layout = {
      default_direction = "right",
      width = 34,
      min_width = 28,
    },
    attach_mode = "window",
    backends = { "treesitter", "lsp", "markdown", "man" },
    show_guides = true,
    filter_kind = false, -- show variables too (like WebStorm)
    icons = {},
    nerd_font = "all",
  },
}
