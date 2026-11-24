local M = {}
local api = vim.api
local active
function M.mouse(prompt)
  if not vim.b[prompt].movim_search_prompt then return false end
  local picker = require('telescope.actions.state').get_current_picker(prompt)
  local position = vim.fn.getmousepos()
  if not picker or position.winid ~= picker.preview_win then return false end
  vim.schedule(function()
    if api.nvim_buf_is_valid(prompt) then M.edit(prompt, position) end
  end)
  return true
end
function M.edit(prompt, position)
  if active then return end
  local picker = require('telescope.actions.state').get_current_picker(prompt)
  local entry = picker:get_selection()
  if not entry then return end
  local path = require('telescope.from_entry').path(entry, false, false)
  if not path or path == '' then return end
  if not path:match('^%a:[/\\]') and not path:match('^[/\\]') then path = picker.cwd .. '/' .. path end
  if vim.fn.filereadable(path) ~= 1 then return vim.notify('Cannot edit this search result', vim.log.levels.WARN) end
  local buf = vim.fn.bufadd(path)
  local ok, err = pcall(vim.fn.bufload, buf)
  if not ok then return vim.notify(tostring(err), vim.log.levels.ERROR) end
  vim.bo[buf].buflisted = true
  vim.bo[buf].bufhidden = 'hide'
  local preview = picker.preview_win
  local preview_buffer = preview and api.nvim_win_is_valid(preview) and api.nvim_win_get_buf(preview)
  local config
  if preview and api.nvim_win_is_valid(preview) then
    local pos = api.nvim_win_get_position(preview)
    config = { row = math.max(0, pos[1] - 1), col = math.max(0, pos[2] - 1),
      width = api.nvim_win_get_width(preview), height = api.nvim_win_get_height(preview) }
  else
    local width, height = math.max(1, math.floor(vim.o.columns * .8)), math.max(1, math.floor(vim.o.lines * .6))
    config = { row = math.floor((vim.o.lines - height) / 2) - 1, col = math.floor((vim.o.columns - width) / 2), width = width, height = height }
  end
  config.relative, config.style, config.border, config.zindex = 'editor', 'minimal', 'rounded', 70
  config.title = ' Edit: ' .. vim.fs.basename(path) .. ' '
  config.footer = ' i edit · Ctrl+S save · Ctrl+E search '
  local handlers = api.nvim_get_autocmds({ group = 'PickerInsert', event = 'BufLeave', buffer = prompt })
  for _, handler in ipairs(handlers) do api.nvim_del_autocmd(handler.id) end
  vim.cmd('stopinsert')
  local opened, win = pcall(api.nvim_open_win, buf, true, config)
  local function rearm()
    if not api.nvim_buf_is_valid(prompt) then return end
    for _, handler in ipairs(handlers) do
      api.nvim_create_autocmd('BufLeave', { group = 'PickerInsert', buffer = prompt, once = handler.once,
        nested = true, callback = handler.callback, command = handler.command ~= '' and handler.command or nil })
    end
  end
  if not opened then rearm(); return vim.notify(tostring(win), vim.log.levels.ERROR) end
  vim.wo[win].number, vim.wo[win].cursorline = true, true
  local line = math.max(1, math.min(position and position.line or entry.lnum or 1, api.nvim_buf_line_count(buf)))
  local text = api.nvim_buf_get_lines(buf, line - 1, line, false)[1] or ''
  local column = position and position.column or entry.col or 1
  api.nvim_win_set_cursor(win, { line, math.min(math.max(0, column - 1), #text) })
  local group = api.nvim_create_augroup('MovimSearchPreview', { clear = true })
  local mappings = {}
  local closed = false
  local function finish(return_to_search)
    if closed then return end
    closed, active = true, nil
    api.nvim_del_augroup_by_id(group)
    for _, item in ipairs(mappings) do
      pcall(vim.keymap.del, item.mode, item.lhs, { buffer = buf })
      if item.old and api.nvim_buf_is_valid(buf) then api.nvim_buf_call(buf, function() vim.fn.mapset(item.mode, false, item.old) end) end
    end
    if api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
    if api.nvim_buf_is_valid(prompt) and api.nvim_win_is_valid(picker.prompt_win) then
      if return_to_search then api.nvim_set_current_win(picker.prompt_win) end
      rearm()
      local scratch = preview and api.nvim_win_is_valid(preview) and api.nvim_win_get_buf(preview)
      if scratch and scratch == preview_buffer and picker:get_selection() == entry and scratch ~= buf and vim.bo[scratch].buftype == 'nofile' then
        local modifiable = vim.bo[scratch].modifiable
        vim.bo[scratch].modifiable = true
        api.nvim_buf_set_lines(scratch, 0, -1, false, api.nvim_buf_get_lines(buf, 0, -1, false))
        vim.bo[scratch].modifiable = modifiable
      end
      if return_to_search then vim.cmd('startinsert') end
    end
  end
  active = { win = win, buffer = buf, finish = finish }
  for _, mode in ipairs({ 'n', 'i' }) do
    for lhs, callback in pairs({ ['<C-e>'] = function() finish(true) end,
      ['<C-s>'] = function()
        local saved, failure = pcall(api.nvim_buf_call, buf, function() vim.cmd('write') end)
        if not saved then vim.notify(tostring(failure), vim.log.levels.ERROR) end
      end }) do
      local old = vim.fn.maparg(lhs, mode, false, true)
      mappings[#mappings + 1] = { mode = mode, lhs = lhs, old = old.buffer == 1 and old or nil }
      vim.keymap.set(mode, lhs, callback, { buffer = buf, silent = true })
    end
  end
  api.nvim_create_autocmd('WinLeave', { group = group, callback = function()
    if api.nvim_get_current_win() == win then vim.schedule(function() finish(false) end) end
  end })
  api.nvim_create_autocmd('WinClosed', { group = group, pattern = tostring(win), callback = function() vim.schedule(function() finish(true) end) end })
  api.nvim_create_autocmd('BufWipeout', { group = group, buffer = prompt, callback = function() vim.schedule(function() finish(false) end) end })
end
return M
