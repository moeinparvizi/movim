-- neo-tree — file explorer with git status (incl. unversioned files)
return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  cmd = "Neotree",
  init = function()
    -- Netrw is disabled; Neo-tree still clears its group when taking over.
    vim.api.nvim_create_augroup('FileExplorer', { clear = false })
  end,
  dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons", "MunifTanjim/nui.nvim" },
  keys = {
    { "<leader>e", "<cmd>Neotree toggle left<CR>", desc = "File explorer" },
    { "<leader>ge", function() require('utils.git_project').tree() end, desc = "Git status explorer (choose project)" },
    { "<leader>be", "<cmd>Neotree float buffers<CR>", desc = "Buffers explorer" },
  },
  opts = {
    close_if_last_window = false,
    popup_border_style = "rounded",
    default_source = "filesystem",
    sources = { "filesystem", "buffers", "git_status" },
    enable_diagnostics = true,
    filesystem = {
      commands = {
        movim_hide = function(state) require('utils.explorer_filter').hide(state) end,
        movim_hidden = function() require('utils.explorer_filter').edit() end,
      },
      window = { mappings = { ['I'] = 'movim_hide', ['E'] = 'movim_hidden' } },
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,
      filtered_items = {
        visible = false,
        hide_dotfiles = false,
        hide_gitignored = false,
        hide_by_pattern = { "node_modules", ".movim" },
      },
    },
    git_status = {
      window = { position = "float" },
      symbols = {
        -- matches WebStorm colors: green=staged, amber=modified, gray=unversioned
        added = "✚",
        modified = "",
        deleted = "✖",
        renamed = "󰁕",
        untracked = "",
        ignored = "󰘓",
        unstaged = "󰄱",
        staged = "",
        conflict = "",
      },
    },
    window = {
      width = 32,
      auto_expand_width = false,
      mappings = {
        ["<space>"] = "none",
        ["l"] = "open",
        ["h"] = "close_node",
        ["P"] = "toggle_preview",
      },
    },
    event_handlers = {
      { event = 'state_created', handler = function(state) require('utils.explorer_filter').apply(state) end },
      { event = 'after_render', handler = function(state)
        local workspace = require('utils.workspace')
        if state.name ~= 'filesystem' or not state.path or vim.fs.normalize(state.path):gsub('/$', '') ~= workspace.root then return end
        if workspace.explorer_loading == workspace.root and state.winid and vim.api.nvim_win_is_valid(state.winid) then
          local width = workspace.preference('explorer_width', 32)
          vim.api.nvim_win_set_width(state.winid, math.max(15, math.min(width, vim.o.columns - 20)))
          workspace.explorer_loading = nil
        end
        workspace.capture_explorer(state)
      end },
      {
        event = 'neo_tree_window_after_open',
        handler = function(args)
          if args.position == 'float' or not args.winid or not vim.api.nvim_win_is_valid(args.winid) then return end
          local width = require('utils.workspace').preference('explorer_width', 32)
          vim.api.nvim_win_set_width(args.winid, math.max(15, math.min(width, vim.o.columns - 20)))
          vim.wo[args.winid].winfixwidth = true
          require('utils.workspace').queue()
        end,
      },
      {
        event = 'neo_tree_window_before_close',
        handler = function(args)
          if not require('utils.workspace').restoring and args.position ~= 'float' and args.winid and vim.api.nvim_win_is_valid(args.winid) then
            require('utils.workspace').capture_sizes()
          end
        end,
      },
      {
        event = "file_opened",
        handler = function()
          require("neo-tree.command").execute({ action = "close" })
        end,
      },
    },
  },
}
