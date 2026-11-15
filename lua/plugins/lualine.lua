-- lualine — statusline with git branch, diagnostics, Persian-input indicator
return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    options = {
      theme = "auto",
      icons_enabled = true,
      globalstatus = true,
      component_separators = { left = "", right = "" },
      section_separators = { left = "", right = "" },
    },
    sections = {
      lualine_a = { "mode" },
      lualine_b = { "branch", "diff" },
      lualine_c = {
        {
          "filename",
          path = 1,
          symbols = { modified = "●", readonly = "[RO]", unnamed = "[No Name]" },
        },
      },
      lualine_x = {
        {
          function()
            if vim.bo.iminsert == 1 and vim.bo.keymap ~= "" then
              return "FA"
            end
            return ""
          end,
          color = { fg = "#ff9e64", gui = "bold" },
          separator = "",
        },
        { "diagnostics", symbols = { error = "E:", warn = "W:", info = "I:", hint = "H:" } },
        { function() local names = {}; for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do names[#names+1] = c.name end; return #names > 0 and ("LSP:" .. table.concat(names, ",")) or "" end },
        { "filetype" },
      },
      lualine_y = { "progress" },
      lualine_z = { "location" },
    },
  },
}
