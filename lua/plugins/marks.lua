-- marks.nvim — Vim letter marks and optional numbered bookmark groups.
return {
  "chentoast/marks.nvim",
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    default_mappings = true,
    builtin_marks = { ".", "<", ">", "^" },
    cyclic = true,
    force_write_shada = false,
    refresh_interval = 250,
    sign_priority = { lower = 10, upper = 15, builtin = 8, bookmark = 20 },
    excluded_filetypes = { "neo-tree", "lazy", "mason" },
    mappings = {},
  },
}
