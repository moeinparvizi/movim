-- Session restore + dashboard + notifications + indent guides
return {
  {
    "folke/persistence.nvim",
    enabled = false, -- Replaced by utils.workspace, including unsaved drafts.
  },
  {
    "nvimdev/dashboard-nvim",
    event = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      theme = "doom",
      hide = { tabline = false },
      config = {
        vertical_center = true,
        header = {
          [[  __  __  _____ __      __ ___ __  __ ]],
          [[ |  \/  |/ _ \ \/ /\ / /|_ _|  \/  |]],
          [[ | |\/| | | | \  /\ V /  | || |\/| |]],
          [[ |_|  |_|\___/ \/  \_/  |___|_|  |_|]],
          "",
          "movim",
          "",
        },
        center = {
          { desc = " Find file", group = "Label", action = "Telescope find_files", key = "f" },
          { desc = " Recent", group = "Label", action = "Telescope oldfiles", key = "r" },
          { desc = " Git (lazygit)", group = "Label", action = "lua require('utils.term').lazygit()", key = "g" },
          { desc = " Project workspaces", group = "Label", action = "Workspaces", key = "p" },
          { desc = " Open project folder", group = "Label", action = "WorkspaceOpen", key = "o" },
          { desc = " Restore last workspace", group = "Label", action = "WorkspaceLast", key = "s" },
          { desc = " Explorer", group = "Label", action = "Neotree toggle left", key = "e" },
          { desc = " Update movim", group = "Label", action = "MovimUpdate", key = "u" },
        },
        footer = { "Documentation: https://moeinparvizi.github.io/movim/docs-en/README.html" },
      },
    },
    config = function(_, opts)
      -- Dashboard's default uses the whole terminal width even in a split.
      require("dashboard.utils").center_align = function(lines)
        local width = vim.api.nvim_win_get_width(0)
        local result = {}
        for _, line in ipairs(lines) do
          local padding = math.max(0, math.floor((width - vim.fn.strdisplaywidth(line)) / 2))
          result[#result + 1] = (" "):rep(padding) .. line
        end
        return result
      end
      local dashboard = require('dashboard')
      -- The plugin drops its options after leaving the dashboard. Its async
      -- disk-cache callback can then render into a deleted/replaced buffer
      -- during quick project switches. Our options are already in memory.
      dashboard.setup(opts)
      local configured = vim.deepcopy(dashboard.opts)
      getmetatable(dashboard).get_opts = function(_, callback) callback(vim.deepcopy(configured)) end
    end,
  },
  {
    "rcarriga/nvim-notify",
    event = "VeryLazy",
    opts = { timeout = 2500, max_width = 60, stages = "fade_in_slide_out" },
    config = function(_, opts)
      local notify = require("notify")
      notify.setup(opts)
      vim.notify = notify
    end,
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    event = { "BufReadPost", "BufNewFile" },
    main = "ibl",
    opts = {
      indent = { char = "│", tab_char = "│" },
      scope = { enabled = true, show_start = false, show_end = false },
    },
  },
}
