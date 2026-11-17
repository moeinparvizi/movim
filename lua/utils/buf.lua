-- Small buffer helpers
local M = {}

-- Delete buffer without destroying the window layout
function M.delete_safe(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) then return end
  if vim.bo[buf].modified then
    local choice = vim.fn.confirm("Buffer is modified. Save changes?", "&Save\n&Discard\n&Cancel")
    if choice == 1 then
      local ok, err = pcall(vim.api.nvim_buf_call, buf, function() vim.cmd('write') end)
      if not ok then vim.notify('Could not save buffer: ' .. tostring(err), vim.log.levels.ERROR); return end
    elseif choice ~= 2 then
      return
    end
  end
  local replacement
  for _, candidate in ipairs(vim.api.nvim_list_bufs()) do
    if candidate ~= buf and vim.bo[candidate].buflisted and vim.bo[candidate].buftype == '' then
      replacement = candidate
    end
  end
  local windows = vim.fn.win_findbuf(buf)
  if #windows == 0 then vim.api.nvim_buf_delete(buf, { force = true }); return end
  replacement = replacement or vim.api.nvim_create_buf(false, true)
  -- Replace the file in every split before deleting it. :bdelete can close
  -- windows and leave Neo-tree as the last window, causing an editor exit.
  for _, win in ipairs(windows) do vim.api.nvim_win_set_buf(win, replacement) end
  vim.api.nvim_buf_delete(buf, { force = true })
  if vim.bo[replacement].buftype == 'nofile' and #windows > 0 then
    vim.api.nvim_win_call(windows[1], function() M.dashboard() end)
    local dashboard = vim.api.nvim_win_get_buf(windows[1])
    for i = 2, #windows do vim.api.nvim_win_set_buf(windows[i], dashboard) end
  end
end

function M.dashboard()
  -- The command loads the same dashboard used on startup, also in a split.
  local ok = pcall(vim.cmd, 'Dashboard')
  if not ok then
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(0, buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'movim', '', 'Space ff: Find files', 'Space qp: Project workspaces' })
    vim.bo[buf].modifiable = false
    vim.bo[buf].filetype = 'dashboard'
  end
end

return M
