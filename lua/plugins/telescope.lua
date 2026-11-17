-- Telescope — fuzzy finder (files, text search, symbols, git, help…)
return {
  "nvim-telescope/telescope.nvim",
  cmd = "Telescope",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-tree/nvim-web-devicons", opts = {} },
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    { "debugloop/telescope-undo.nvim" },
  },
  keys = {
    { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Find files" },
    { "<leader>fr", "<cmd>Telescope oldfiles<CR>", desc = "Recent files" },
    { "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "Grep in project" },
    { "<leader>fg", function() require("utils.scoped_find").selection() end, mode = "x", desc = "Grep selected text in project" },
    { "<leader>f/", "<cmd>Telescope current_buffer_fuzzy_find<CR>", desc = "Search in current file" },
    { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Buffers" },
    { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "Help pages" },
    { "<leader>fc", "<cmd>Telescope command_history<CR>", desc = "Command history" },
    { "<leader>fw", "<cmd>Telescope grep_string<CR>", desc = "Grep word under cursor" },
    { "<leader>gu", function() require('utils.git_project').telescope('git_status') end, desc = "Git status (choose project)" },
    { "<leader>gL", function() require('utils.git_project').telescope('git_commits') end, desc = "Git commits (choose project)" },
    { "<leader>gb", function() require('utils.git_project').telescope('git_branches') end, desc = "Git branches (choose project)" },
    { "<leader>ss", "<cmd>Telescope lsp_document_symbols<CR>", desc = "Document symbols" },
    { "<leader>sS", "<cmd>Telescope lsp_workspace_symbols<CR>", desc = "Workspace symbols" },
    { "<leader>sk", "<cmd>Telescope keymaps<CR>", desc = "Keymaps" },
    { "<leader>sc", "<cmd>Telescope commands<CR>", desc = "Commands" },
    { "<leader>st", "<cmd>TodoTelescope<CR>", desc = "TODO list" },
    { "<leader>sn", "<cmd>Telescope notify<CR>", desc = "Notification history" },
    { "<leader>ut", function() require("config.theme").picker() end, desc = "Browse and install themes" },
  },
  opts = {
    defaults = {
      attach_mappings = function(buf, map) return require('utils.search_clear').telescope(buf, map) end,
      prompt_prefix = " ",
      selection_caret = " ",
      path_display = { "smart" },
      sorting_strategy = "ascending",
      layout_config = {
        horizontal = { prompt_position = "top", preview_width = 0.55 },
        vertical = { mirror = false },
      },
      mappings = {
        i = {
          ["<C-j>"] = function(...) require("telescope.actions").move_selection_next(...) end,
          ["<C-k>"] = function(...) require("telescope.actions").move_selection_previous(...) end,
          ["<C-d>"] = function(...) require("telescope.actions").preview_scrolling_down(...) end,
        },
      },
    },
  },
  config = function(_, opts)
    local t = require("telescope")
    t.setup(opts)
    -- Builtins such as current_buffer_fuzzy_find replace attach_mappings.
    vim.api.nvim_create_autocmd('FileType', {
      group = vim.api.nvim_create_augroup('movim-search-inputs', { clear = true }),
      pattern = 'TelescopePrompt', callback = function(args)
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(args.buf) then require('utils.search_clear').telescope(args.buf) end
        end)
      end,
    })
    require("utils.scoped_find").install()
    pcall(t.load_extension, "fzf")
    pcall(t.load_extension, "undo")
    pcall(t.load_extension, "notify")
  end,
}
