local M = {}
local api = vim.api
local last_clipboard = {}
local function settings()
  return require('utils.workspace').preference('clipboard', { limit = 50, history = {} })
end
local function save(value)
  require('utils.workspace').preference('clipboard', {}, vim.deepcopy(value))
end
function M.items()
  return vim.deepcopy(settings().history or {})
end
function M.record(lines, regtype)
  if type(lines) ~= 'table' or #lines == 0 or (#lines == 1 and lines[1] == '') then return end
  local value = vim.deepcopy(settings())
  local limit = math.max(1, math.min(200, tonumber(value.limit) or 50))
  value.history = value.history or {}
  for index = #value.history, 1, -1 do
    if vim.deep_equal(value.history[index].lines, lines) and value.history[index].regtype == regtype then table.remove(value.history, index) end
  end
  table.insert(value.history, 1, { lines = vim.deepcopy(lines), regtype = regtype or 'v' })
  while #value.history > limit do table.remove(value.history) end
  save(value)
end
function M.remove(index)
  local value = vim.deepcopy(settings())
  table.remove(value.history or {}, index)
  save(value)
end
function M.clear()
  local value = vim.deepcopy(settings())
  value.history = {}
  save(value)
end
function M.capture()
  local ok, register = pcall(vim.fn.getreginfo, '+')
  if not ok or not register.regcontents or #register.regcontents == 0 then return end
  local root = require('utils.workspace').root or vim.fn.getcwd()
  if vim.deep_equal(last_clipboard[root], register.regcontents) then return end
  last_clipboard[root] = vim.deepcopy(register.regcontents)
  local first = M.items()[1]
  if first and vim.deep_equal(first.lines, register.regcontents) then return end
  M.record(register.regcontents, register.regtype)
end
function M.paste(item, target)
  if not item or not api.nvim_win_is_valid(target.win) or not api.nvim_buf_is_valid(target.buf) then return end
  if api.nvim_win_get_buf(target.win) ~= target.buf or not vim.bo[target.buf].modifiable then return end
  api.nvim_set_current_win(target.win)
  local virtualedit = vim.wo[target.win].virtualedit
  if target.insert then vim.wo[target.win].virtualedit = 'onemore' end
  api.nvim_win_set_cursor(target.win, target.cursor)
  api.nvim_put(item.lines, item.regtype or 'v', not target.insert, true)
  if target.insert then vim.wo[target.win].virtualedit = virtualedit end
  if target.insert then vim.cmd('startinsert') end
end
function M.open(target, skip_capture)
  target = target or { win = api.nvim_get_current_win(), buf = api.nvim_get_current_buf(),
    cursor = api.nvim_win_get_cursor(0), insert = vim.fn.mode():sub(1, 1) == 'i' }
  if not vim.bo[target.buf].modifiable or vim.bo[target.buf].buftype ~= '' then return end
  if not skip_capture then M.capture() end
  local items = M.items()
  local function restore()
    if api.nvim_win_is_valid(target.win) and api.nvim_win_get_buf(target.win) == target.buf then
      api.nvim_set_current_win(target.win)
      api.nvim_win_set_cursor(target.win, target.cursor)
      if target.insert then vim.cmd('startinsert') end
    end
  end
  if #items == 0 then restore(); return vim.notify('Clipboard history is empty. Copy some text first.') end
  local actions = require('telescope.actions')
  local state = require('telescope.actions.state')
  require('telescope.pickers').new({}, {
    prompt_title = 'Clipboard | Enter: paste | Ctrl+D: delete | Ctrl+X: clear',
    finder = require('telescope.finders').new_table({ results = items, entry_maker = function(item)
      local text = table.concat(item.lines, ' ')
      return { value = item, display = vim.fn.strcharpart(text, 0, 160) .. (#item.lines > 1 and ('  [' .. #item.lines .. ' lines]') or ''), ordinal = text }
    end }),
    sorter = require('telescope.config').values.generic_sorter({}),
    previewer = require('telescope.previewers').new_buffer_previewer({ define_preview = function(self, entry)
      api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, entry.value.lines)
    end }),
    attach_mappings = function(prompt, map)
      actions.select_default:replace(function()
        local entry = state.get_selected_entry()
        actions.close(prompt)
        vim.schedule(function() if entry then M.paste(entry.value, target) end end)
      end)
      for _, mode in ipairs({ 'i', 'n' }) do
        map(mode, '<Esc>', function() actions.close(prompt); vim.schedule(restore) end)
        map(mode, '<C-d>', function()
          local entry = state.get_selected_entry()
          if not entry then return end
          for index, item in ipairs(M.items()) do if vim.deep_equal(item, entry.value) then M.remove(index); break end end
          actions.close(prompt)
          vim.schedule(function() M.open(target, true) end)
        end)
        map(mode, '<C-x>', function() M.clear(); actions.close(prompt); vim.schedule(restore) end)
      end
      return true
    end,
  }):find()
end
function M.setup()
  local group = api.nvim_create_augroup('MovimClipboardHistory', { clear = true })
  api.nvim_create_autocmd('TextYankPost', { group = group, callback = function()
    if vim.v.event.operator == 'y' then M.record(vim.v.event.regcontents, vim.v.event.regtype) end
  end })
  api.nvim_create_autocmd('FocusGained', { group = group, callback = function() vim.schedule(M.capture) end })
  api.nvim_create_user_command('ClipboardHistory', function() M.open() end, { desc = 'Choose copied text to paste' })
  api.nvim_create_user_command('ClipboardHistoryClear', M.clear, { desc = 'Clear project clipboard history' })
  vim.keymap.set({ 'n', 'i' }, '<C-S-v>', function() M.open() end, { desc = 'Paste from clipboard history' })
  vim.keymap.set('n', '<leader>hy', function() M.open() end, { desc = 'Clipboard history' })
end
return M
