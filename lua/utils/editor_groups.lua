local M = {}

local function editors()
  local result = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_win_get_config(win).relative == '' and vim.bo[buf].buftype == ''
      and not vim.tbl_contains({ 'neo-tree', 'dashboard' }, vim.bo[buf].filetype) then
      result[#result + 1] = win
    end
  end
  return result
end

function M.refresh()
  local wins = editors()
  for _, win in ipairs(wins) do
    if #wins > 1 then
      vim.wo[win].winbar = ' %t %m'
      vim.w[win].movim_group_winbar = true
    elseif vim.w[win].movim_group_winbar then
      vim.wo[win].winbar = ''
      vim.w[win].movim_group_winbar = nil
    end
  end
end

function M.split(vertical)
  local original = vim.api.nvim_get_current_win()
  local size = vertical and vim.api.nvim_win_get_width(original) or vim.api.nvim_win_get_height(original)
  vim.cmd(vertical and 'vsplit' or 'split')
  local current = vim.api.nvim_get_current_win()
  if vertical then vim.api.nvim_win_set_width(current, math.max(1, math.floor((size - 1) / 2)))
  else vim.api.nvim_win_set_height(current, math.max(1, math.floor((size - 1) / 2))) end
  M.refresh()
end

function M.setup()
  local group = vim.api.nvim_create_augroup('movim-editor-groups', { clear = true })
  vim.api.nvim_create_autocmd({ 'WinNew', 'WinClosed', 'BufWinEnter', 'TabEnter' }, {
    group = group, callback = function() vim.schedule(M.refresh) end,
  })
end

return M
