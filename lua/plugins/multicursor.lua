-- multiple-cursors — Ctrl+Click adds a cursor, exactly like WebStorm.
-- Esc returns to normal mode; edits apply to every cursor.
local saved_virtualedit
local cursor_window
return {
  "brenton-leighton/multiple-cursors.nvim",
  version = "*",
  keys = {
    { "<C-LeftMouse>", "<cmd>MultipleCursorsMouseAddDelete<CR>", mode = "n", desc = "Toggle cursor at mouse (Ctrl+Click)" },
    { "<C-Down>", "<cmd>MultipleCursorsAddDown<CR>", mode = "n", desc = "Add cursor below" },
    { "<C-Up>", "<cmd>MultipleCursorsAddUp<CR>", mode = "n", desc = "Add cursor above" },
    { "<C-n>", "<cmd>MultipleCursorsAddJumpNextMatch<CR>", mode = { "n", "x" }, desc = "Select next match" },
    { "<leader>ma", "<cmd>MultipleCursorsAddMatches<CR>", mode = { "n", "x" }, desc = "Select all visible matches" },
    { "<leader>mn", "<cmd>MultipleCursorsAddJumpNextMatch<CR>", mode = { "n", "x" }, desc = "Select next match" },
    { "<leader>ms", "<cmd>MultipleCursorsJumpNextMatch<CR>", mode = { "n", "x" }, desc = "Skip to next match" },
  },
  opts = {
    pre_hook = function()
      cursor_window = vim.api.nvim_get_current_win()
      saved_virtualedit = vim.wo[cursor_window].virtualedit
      local values = vim.split(saved_virtualedit, ",", { trimempty = true })
      if not vim.tbl_contains(values, "all") and not vim.tbl_contains(values, "onemore") then
        values[#values + 1] = "onemore"
        vim.wo[cursor_window].virtualedit = table.concat(values, ",")
      end
    end,
    post_hook = function()
      if cursor_window and vim.api.nvim_win_is_valid(cursor_window) then
        vim.wo[cursor_window].virtualedit = saved_virtualedit
      end
      cursor_window, saved_virtualedit = nil, nil
    end,
  },
  config = function(_, opts)
    require("multiple-cursors").setup(opts)
    -- The plugin treats selected text as a Vim pattern; selections should be literal.
    local search = require("multiple-cursors.search")
    for _, name in ipairs({ "get_matches_and_move_cursor", "get_next_match" }) do
      local original = search[name]
      search[name] = function(pattern, ...)
        if pattern and vim.api.nvim_get_mode().mode == "v" then
          pattern = "\\V" .. pattern:gsub("\\", "\\\\")
        end
        return original(pattern, ...)
      end
    end
  end,
}
