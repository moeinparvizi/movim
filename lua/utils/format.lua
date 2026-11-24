local M = {}
function M.run(range)
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype ~= '' or not vim.bo[buf].modifiable then return end
  local conform = require('conform')
  local formatters = conform.list_formatters_to_run(buf)
  local method = range and 'textDocument/rangeFormatting' or 'textDocument/formatting'
  if #formatters == 0 and #vim.lsp.get_clients({ bufnr = buf, method = method }) == 0 then
    return vim.notify('No formatter available for ' .. vim.bo[buf].filetype .. '. See :ConformInfo or install one with :Mason.', vim.log.levels.WARN)
  end
  conform.format({ bufnr = buf, async = true, lsp_format = 'fallback', range = range }, function(err)
    if err then vim.notify('Formatting failed: ' .. tostring(err), vim.log.levels.ERROR) end
  end)
end
function M.lines(first, last)
  local text = vim.api.nvim_buf_get_lines(0, last - 1, last, false)[1] or ''
  M.run({ start = { first, 0 }, ['end'] = { last, #text } })
end
function M.line()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  M.lines(row, row)
end
function M.selection()
  local first = vim.fn.getpos('v')[2]
  local last = vim.api.nvim_win_get_cursor(0)[1]
  M.lines(math.min(first, last), math.max(first, last))
end
function M.setup()
  vim.api.nvim_create_user_command('Format', function(opts)
    if opts.range > 0 then M.lines(opts.line1, opts.line2) else M.run() end
  end, { range = true, desc = 'Format file or selected lines' })
  vim.api.nvim_create_user_command('FormatLine', M.line, { desc = 'Format current line' })
  vim.keymap.set('n', '<leader>cf', function() M.run() end, { desc = 'Format file' })
  vim.keymap.set('x', '<leader>cf', M.selection, { desc = 'Format selected lines' })
  vim.keymap.set('n', '<leader>cF', M.line, { desc = 'Format current line' })
  vim.keymap.set({ 'n', 'i' }, '<C-M-l>', function() M.run() end, { desc = 'Reformat code' })
  vim.keymap.set('x', '<C-M-l>', M.selection, { desc = 'Reformat selected lines' })
end
return M
