local M = { position = 'right', size = 60 }
local api = vim.api
local sessions = require('movim_ai.sessions')
local function lines(text) return vim.split(tostring(text or ''), '\n', { plain = true }) end
function M.visible() return M.win and api.nvim_win_is_valid(M.win) end
function M.render()
  if not M.buf or not api.nvim_buf_is_valid(M.buf) then return end
  local output = { 'AI Panel', '' }
  for _, tab in ipairs(sessions.tabs) do
    output[#output + 1] = ('%s [%d] %s — %s'):format(tab.id == sessions.selected and '>' or ' ', tab.id, tab.name, tab.status)
  end
  output[#output + 1] = ''
  output[#output + 1] = ':AIChat  :AINew  :AISelect  :AIRename  :AICloseTab'
  output[#output + 1] = ':AIAttach  :AIFile  :AIRefresh  :AIRemove  :AICancel'
  output[#output + 1] = ':AIPreview  :AIApply  :AIReject  :AIRevise  :AIRerun'
  output[#output + 1] = ':AIMove left|right|top|bottom   :AIResize 60'
  output[#output + 1] = ':AIConfigure  (provider/model; API key stays in environment)'
  local tab
  for _, value in ipairs(sessions.tabs) do if value.id == sessions.selected then tab = value end end
  if tab then
    output[#output + 1] = ''; output[#output + 1] = 'Attachments (buffer snapshots):'
    for _, s in ipairs(tab.attachments) do
      local current = require('movim_ai.editor').current(s)
      output[#output + 1] = ('  %s | tick %d | %s | %s'):format(s.path ~= '' and s.path or '[unnamed]', s.tick, s.id, current and 'current' or 'STALE')
    end
    for _, s in pairs(tab.contexts) do
      local current = require('movim_ai.editor').current(s)
      output[#output + 1] = ('  Conversation context: %s | tick %d | %s'):format(s.path ~= '' and s.path or '[unnamed]', s.tick, current and 'current' or 'STALE — :AIRefresh')
    end
    for _, entry in ipairs(tab.history) do
      output[#output + 1] = ''; output[#output + 1] = '── ' .. entry.role .. ' ──'
      vim.list_extend(output, lines(entry.text))
    end
    local r = tab.request
    if r then
      if r.snapshot then
        output[#output + 1] = ''
        output[#output + 1] = ('Selection: %s | %s | tick %d'):format(r.snapshot.path, r.snapshot.id, r.snapshot.tick)
      end
      if r.status == 'processing' then output[#output + 1] = 'Streaming…'; vim.list_extend(output, lines(r.output)) end
      if r.error then output[#output + 1] = 'ERROR: ' .. r.error end
      if r.status == 'review' then
        output[#output + 1] = ''; output[#output + 1] = 'Ready for review — :AIPreview → :AIApply / :AIReject / :AIRevise'
        vim.list_extend(output, lines(r.proposal.explanation))
      end
    end
  end
  vim.bo[M.buf].modifiable = true
  api.nvim_buf_set_lines(M.buf, 0, -1, false, output)
  vim.bo[M.buf].modifiable = false
end
function M.open(position)
  if position then M.position = position end
  if M.visible() then api.nvim_set_current_win(M.win); return end
  local current = api.nvim_get_current_buf()
  if vim.bo[current].buftype == '' then M.source = current end
  if not M.buf or not api.nvim_buf_is_valid(M.buf) then
    M.buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_name(M.buf, 'movim://AI Panel')
    vim.bo[M.buf].bufhidden = 'hide'; vim.bo[M.buf].filetype = 'movim-ai'
    for action, key in pairs(M.config.panel_keys) do
      if key ~= false and M.actions[action] then vim.keymap.set('n', key, M.actions[action], { buffer = M.buf, silent = true, desc = 'AI Panel: ' .. action }) end
    end
  end
  local commands = { right = 'botright vsplit', left = 'topleft vsplit', top = 'topleft split', bottom = 'botright split' }
  vim.cmd(commands[M.position])
  M.win = api.nvim_get_current_win(); api.nvim_win_set_buf(M.win, M.buf)
  vim.wo[M.win].number = false; vim.wo[M.win].relativenumber = false; vim.wo[M.win].wrap = true
  vim.wo[M.win].signcolumn = 'no'; vim.wo[M.win].winfixwidth = true
  M.resize(M.size)
  sessions.current(); M.render()
end
function M.hide() if M.visible() then api.nvim_win_close(M.win, false) end; M.win = nil end
function M.toggle() if M.visible() then M.hide() else M.open() end end
function M.resize(size)
  M.size = math.max(8, math.min(tonumber(size) or 60, 200))
  if M.visible() then
    if M.position == 'left' or M.position == 'right' then api.nvim_win_set_width(M.win, M.size)
    else api.nvim_win_set_height(M.win, math.min(M.size, math.max(8, math.floor(vim.o.lines / 2)))) end
  end
end
function M.move(position)
  assert(vim.tbl_contains({ 'left', 'right', 'top', 'bottom' }, position), 'Choose left, right, top or bottom')
  M.hide(); M.open(position)
end
function M.preview(request)
  assert(request and request.status == 'review', 'No proposal ready for review')
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'; vim.bo[buf].filetype = 'diff'
  local content = { 'AI Panel — selection-only preview', request.proposal.explanation, '', '--- original selection', '+++ proposed selection' }
  vim.list_extend(content, lines(require('movim_ai.apply').diff(request, request.proposal)))
  api.nvim_buf_set_lines(buf, 0, -1, false, content); vim.bo[buf].modifiable = false
  api.nvim_open_win(buf, true, { relative = 'editor', row = 2, col = 3,
    width = math.max(20, vim.o.columns - 6), height = math.max(5, vim.o.lines - 6), style = 'minimal', border = 'rounded', title = ' AI Panel · Diff ' })
  vim.keymap.set('n', 'q', '<Cmd>close<CR>', { buffer = buf })
  vim.keymap.set('n', '<Esc>', '<Cmd>close<CR>', { buffer = buf })
end
return M
