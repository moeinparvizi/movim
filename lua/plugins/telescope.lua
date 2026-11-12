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
    { "<leader>f/", "<cmd>Telescope current_buffer_fuzzy_find<CR>", desc = "Search in current file" },
    { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Buffers" },
    { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "Help pages" },
    { "<leader>fc", "<cmd>Telescope command_history<CR>", desc = "Command history" },
    { "<leader>fw", "<cmd>Telescope grep_string<CR>", desc = "Grep word under cursor" },
    { "<leader>gu", "<cmd>Telescope git_status<CR>", desc = "Git status (unversioned files…)" },
    { "<leader>gc", "<cmd>Telescope git_commits<CR>", desc = "Git commits" },
    { "<leader>gb", "<cmd>Telescope git_branches<CR>", desc = "Git branches (checkout)" },
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
          ["<C-u>"] = function(...) require("telescope.actions").preview_scrolling_up(...) end,
          ["<C-d>"] = function(...) require("telescope.actions").preview_scrolling_down(...) end,
        },
      },
    },
    pickers = {
      find_files = {
        hidden = true,
        prompt_title = "Find Files | Ctrl+D: folder | Ctrl+X: exclude",
        find_command = function() return { "rg", "--files", "--glob", "!.git/" } end,
        attach_mappings = function(prompt_bufnr, map)
          local ok, scoped_find = pcall(require, "utils.scoped_find")
          if not ok then
            -- A running Neovim may have cached the Lua directory before this file existed.
            local source = debug.getinfo(1, "S").source:sub(2)
            local path = vim.fn.fnamemodify(source, ":p:h:h") .. "/utils/scoped_find.lua"
            local chunk = loadfile(path)
            if chunk then ok, scoped_find = pcall(chunk) end
          end
          if ok then return scoped_find.attach(prompt_bufnr, map) end
          vim.notify("Find Files scope controls could not be loaded; basic search is still available.", vim.log.levels.WARN)
          return true
        end,
      },
      live_grep = {
        prompt_title = "Live Grep | Ctrl+D: folder | Ctrl+X: exclude",
        attach_mappings = function(prompt_bufnr, map)
          local ok, scoped_find = pcall(require, "utils.scoped_find")
          if not ok then
            local source = debug.getinfo(1, "S").source:sub(2)
            local path = vim.fn.fnamemodify(source, ":p:h:h") .. "/utils/scoped_find.lua"
            local chunk = loadfile(path)
            if chunk then ok, scoped_find = pcall(chunk) end
          end
          if ok then return scoped_find.attach(prompt_bufnr, map, nil, "grep") end
          vim.notify("Live Grep scope controls could not be loaded; basic search is still available.", vim.log.levels.WARN)
          return true
        end,
      },
    },
  },
  config = function(_, opts)
    local t = require("telescope")
    t.setup(opts)
    pcall(t.load_extension, "fzf")
    pcall(t.load_extension, "undo")
    pcall(t.load_extension, "notify")
  end,
}
