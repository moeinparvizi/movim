-- Shared mouse button and keyboard action for search inputs.
local M = {}
function M.telescope(buf, map)
  if vim.b[buf].movim_clear_attached then return true end
  local picker = require('telescope.actions.state').get_current_picker(buf)
  if not picker or not picker.prompt_win or not vim.api.nvim_win_is_valid(picker.prompt_win) then return true end
  vim.b[buf].movim_clear_attached = true
  M.attach(buf, picker.prompt_win, function() picker:set_prompt('') end, map)
  return true
end
function M.attach(buf, win, clear, map)
  map = map or function(mode, key, callback)
    vim.keymap.set(mode, key, callback, { buffer = buf, silent = true, desc = 'Clear input' })
  end
  for _, mode in ipairs({ 'i', 'n' }) do map(mode, '<C-u>', clear) end
  local button = vim.api.nvim_create_buf(false, true)
  vim.bo[button].bufhidden = 'wipe'
  vim.api.nvim_buf_set_lines(button, 0, -1, false, { ' × ' })
  vim.bo[button].modifiable = false
  local function config()
    return { relative = 'win', win = win, row = 0, col = math.max(0, vim.api.nvim_win_get_width(win) - 3),
      width = 3, height = 1, style = 'minimal', border = 'none', zindex = 160 }
  end
  local button_win = vim.api.nvim_open_win(button, false, config())
  vim.wo[button_win].winhighlight = 'Normal:NormalFloat'
  local function click()
    if not vim.api.nvim_win_is_valid(win) then return end
    clear()
    -- Let mouse focus and TextChanged callbacks finish before returning input focus.
    vim.schedule(function()
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_set_current_win(win); vim.cmd.startinsert() end
    end)
  end
  vim.keymap.set({ 'n', 'i' }, '<LeftMouse>', click, { buffer = button, silent = true })
  vim.api.nvim_create_autocmd('BufEnter', { buffer = button, callback = function() vim.schedule(click) end })
  local group = vim.api.nvim_create_augroup('movim-search-clear-' .. buf, { clear = true })
  vim.api.nvim_create_autocmd({ 'VimResized', 'WinResized' }, { group = group, callback = function()
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_is_valid(button_win) then
      vim.api.nvim_win_set_config(button_win, config())
    end
  end })
  vim.api.nvim_create_autocmd('BufWipeout', { group = group, buffer = buf, once = true, callback = function()
    if vim.api.nvim_win_is_valid(button_win) then vim.api.nvim_win_close(button_win, true) end
    vim.api.nvim_del_augroup_by_id(group)
  end })
  return button_win
end
return M
