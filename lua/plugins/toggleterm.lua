-- toggleterm — floating/horizontal terminals + lazygit UI (<leader>gg)
return {
  "akinsho/toggleterm.nvim",
  version = "*",
  cmd = { "ToggleTerm", "TermSelect", "LazyGit", "TerminalPanel" },
  keys = {
    { "<C-/>", function() require("utils.terminal_panel").toggle() end, mode = { "n", "t" }, desc = "Toggle terminal panel" },
    { "<leader>tt", function() require("utils.terminal_panel").toggle() end, desc = "Toggle terminal panel" },
    { "<leader>t+", function() require("utils.terminal_panel").new() end, desc = "New terminal tab" },
    { "<leader>t]", function() require("utils.terminal_panel").cycle(1) end, desc = "Next terminal tab" },
    { "<leader>t[", function() require("utils.terminal_panel").cycle(-1) end, desc = "Previous terminal tab" },
    { "<leader>tx", function() require("utils.terminal_panel").close() end, desc = "Close terminal tab" },
    { "<leader>tr", function() require("utils.terminal_panel").rename() end, desc = "Rename terminal tab" },
    { "<leader>t|", function() require("utils.terminal_panel").split() end, desc = "Split terminal panel" },
    { "<leader>th", "<cmd>ToggleTerm direction=horizontal size=15<CR>", desc = "Horizontal terminal" },
    { "<leader>tv", "<cmd>ToggleTerm direction=vertical size=60<CR>", desc = "Vertical terminal" },
    { "<leader>ts", "<cmd>TermSelect<CR>", desc = "Select terminal" },
    {
      "<leader>gg",
      function()
        require("utils.term").lazygit()
      end,
      desc = "lazygit (full git UI)",
    },
  },
  opts = {
    open_mapping = false,
    direction = "float",
    float_opts = { border = "rounded" },
    highlights = { NormalFloat = { link = "Normal" }, FloatBorder = { link = "Comment" } },
  },
  config = function(_, opts)
    require("toggleterm").setup(opts)
    vim.api.nvim_create_user_command("TerminalPanel", function() require("utils.terminal_panel").toggle() end, { desc = "Toggle terminal panel" })
  end,
}
