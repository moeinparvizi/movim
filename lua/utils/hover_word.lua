local M = {}
local active_win, active_match, active_word

local function clear()
  if active_win and vim.api.nvim_win_is_valid(active_win) and active_match then
    pcall(vim.fn.matchdelete, active_match, active_win)
  end
  active_win, active_match, active_word = nil, nil, nil
end

function M.update()
  if vim.fn.mode() ~= "v" or vim.bo.buftype ~= "" then clear(); return end
  local win = vim.api.nvim_get_current_win()
  local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = "v" })
  local word = #lines == 1 and lines[1] or nil
  if not word or word == "" then clear(); return end
  if active_win == win and active_word == word then return end
  clear()
  active_win, active_word = win, word
  local literal = [[\C\V]] .. word:gsub('\\', '\\\\')
  if vim.fn.matchstr(word, [[^\k\+$]]) == word then literal = [[\C\<\V]] .. word:gsub('\\', '\\\\') .. [[\m\>]] end
  active_match = vim.fn.matchadd("MovimHoverWord", literal, 10, -1, { window = win })
end

function M.setup()
  local function highlight()
    local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
    local bg, fg = normal.bg or 0x1a1b26, normal.fg or 0xc0caf5
    local color = 0
    for _, shift in ipairs({ 16, 8, 0 }) do
      local base = bit.band(bit.rshift(bg, shift), 255)
      local front = bit.band(bit.rshift(fg, shift), 255)
      color = color + bit.lshift(math.floor(base * 0.88 + front * 0.12), shift)
    end
    vim.api.nvim_set_hl(0, "MovimHoverWord", { bg = color })
  end
  highlight()
  vim.api.nvim_create_autocmd("ColorScheme", { callback = highlight })
  vim.api.nvim_create_autocmd({ "CursorMoved", "ModeChanged" }, { callback = M.update })
  vim.api.nvim_create_autocmd({ "WinClosed", "BufLeave" }, { callback = clear })
end

return M
