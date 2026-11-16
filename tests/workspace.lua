local repo = vim.fn.getcwd()
vim.opt.rtp:prepend(repo)
vim.o.hidden, vim.o.equalalways = true, false
vim.o.columns, vim.o.lines = 180, 48
local root = vim.env.MOVIM_WORKSPACE_TEST_DIR:gsub('\\', '/')
local phase = vim.env.MOVIM_WORKSPACE_TEST_PHASE
local W = require('utils.workspace')
local options = { directory = root .. '/state' }
if phase ~= 'auto' and phase ~= 'headless' then options.auto_restore = false end
if phase == 'legacy' then options.legacy_directory = root .. '/legacy' end
W.setup(options)
local A, B = root .. '/A', root .. '/B'
local function check(value, message) assert(value, message); print('PASS ' .. message) end
local function text(buf) return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, true), '\n') end
local function named(path) return vim.fn.bufnr(vim.fn.fnamemodify(path, ':p')) end
local function statefile(project)
  local value = vim.fs.normalize(vim.fn.fnamemodify(project, ':p')):gsub('/$', '')
  return root .. '/state/' .. vim.fn.sha256(vim.fn.has('win32') == 1 and value:lower() or value) .. '.json'
end
if phase == 'write' then
  assert(W.open(A, { startup = true }))
  vim.cmd('edit ' .. vim.fn.fnameescape(A .. '/one.txt'))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'unsaved فارسی', 'second' })
  vim.api.nvim_win_set_cursor(0, { 2, 2 })
  vim.cmd('vsplit ' .. vim.fn.fnameescape(A .. '/two.txt'))
  vim.api.nvim_win_set_width(0, 55)
  vim.cmd('tab split'); vim.cmd('enew')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'unnamed draft فارسی' })
  local files = W.search('files'); files.query, files.cwd, files.exclude = 'one', A .. '/src', { 'node_modules/**', '*.lock' }
  W.search('grep').query = 'hello.*world'
  W.preference('explorer_width', 32, 46); W.preference('terminal_height', 15, 12)
  check(W.save(), 'save unsaved buffers and layout')
  check(vim.fn.readfile(A .. '/one.txt')[1] == 'disk', 'workspace save never overwrites source files')
  local before = vim.uv.fs_stat(statefile(A)).mtime
  vim.wait(30); assert(W.save())
  local after = vim.uv.fs_stat(statefile(A)).mtime
  check(before.sec == after.sec and before.nsec == after.nsec, 'unchanged state does not rewrite storage')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'unnamed draft فارسی', 'debounced' })
  W.queue()
  check(vim.wait(2500, function()
    local value = table.concat(vim.fn.readfile(statefile(A)), '\n')
    return value:find('debounced', 1, true) ~= nil
  end), 'debounced checkpoint saves edits before exit')
elseif phase == 'read' then
  assert(W.open(A, { startup = true }))
  local one = named(A .. '/one.txt')
  check(one > 0 and text(one) == 'unsaved فارسی\nsecond' and vim.bo[one].modified, 'fresh process restores unsaved named buffer')
  local draft
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf) == '' and vim.bo[buf].buflisted and text(buf):find('unnamed draft', 1, true) then draft = buf end
  end
  check(draft and text(draft):find('debounced', 1, true), 'fresh process restores unnamed draft')
  check(#vim.api.nvim_list_tabpages() == 2, 'editor tabpages restored')
  local first = vim.api.nvim_list_tabpages()[1]
  check(#vim.api.nvim_tabpage_list_wins(first) == 2, 'split layout restored')
  local two = named(A .. '/two.txt'); local sized, cursor = false, false
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(first)) do
    if vim.api.nvim_win_get_buf(win) == two then sized = math.abs(vim.api.nvim_win_get_width(win) - 55) <= 1 end
    if vim.api.nvim_win_get_buf(win) == one then cursor = vim.api.nvim_win_get_cursor(win)[1] == 2 end
  end
  check(sized and cursor, 'split width and cursor restored')
  check(W.search('files').query == 'one' and #W.search('files').exclude == 2 and W.search('files').cwd == A .. '/src', 'find query, scope and exclusions survive restart')
  check(W.search('grep').query == 'hello.*world', 'grep has independent persistent state')
  check(W.preference('explorer_width', 32) == 46 and W.preference('terminal_height', 15) == 12, 'explorer and terminal sizes survive restart')
  assert(W.open(B)); vim.cmd('edit ' .. vim.fn.fnameescape(B .. '/other.txt'))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'B unsaved' }); W.search('files').query = 'other'
  assert(W.save()); assert(W.open(A))
  check(W.search('files').query == 'one' and text(named(A .. '/one.txt')) == 'unsaved فارسی\nsecond', 'switching projects restores independent drafts and queries')
  local select = vim.ui.select
  vim.ui.select = function(items, _, callback)
    check(#items >= 2, 'previous projects appear in workspace chooser')
    for _, item in ipairs(items) do if item.root:sub(-2) == '/B' then callback(item); return end end
    error('B missing from chooser')
  end
  W.select(); vim.ui.select = select
  check(W.search('files').query == 'other' and text(named(B .. '/other.txt')) == 'B unsaved', 'workspace chooser restores selected project')
  assert(W.open(A))
elseif phase == 'auto' then
  local uis = vim.api.nvim_list_uis
  vim.api.nvim_list_uis = function() return { {} } end
  vim.api.nvim_exec_autocmds('VimEnter', {})
  check(vim.wait(1000, function() return W.root == A end), 'normal startup automatically restores last project')
  vim.api.nvim_list_uis = uis
  check(text(named(A .. '/one.txt')) == 'unsaved فارسی\nsecond', 'automatic startup recovers previous draft')
elseif phase == 'conflict' then
  assert(W.open(A, { startup = true }))
  local recovery
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do if vim.b[buf].movim_recovery_origin == A .. '/one.txt' then recovery = buf end end
  check(recovery and text(recovery) == 'unsaved فارسی\nsecond' and vim.bo[recovery].modified, 'externally changed file keeps a separate recovered draft')
  check(vim.fn.readfile(A .. '/one.txt')[1] == 'external disk change', 'external disk change is preserved')
elseif phase == 'corrupt' then
  assert(W.open(A, { startup = true }))
  vim.fn.writefile({ '{ invalid json' }, statefile(B))
  local current = vim.api.nvim_get_current_buf()
  check(not W.open(B), 'corrupt workspace refuses to restore')
  check(vim.api.nvim_buf_is_valid(current) and vim.fn.readfile(statefile(B))[1] == '{ invalid json', 'corrupt state and current editor are preserved')
  vim.fn.writefile({ vim.json.encode({ version = 1, root = B, buffers = {}, tabs = { { layout = { kind = 'leaf', buffer = 'missing' } } } }) }, statefile(B))
  check(not W.open(B) and vim.api.nvim_buf_is_valid(current), 'invalid layout is rejected before closing current buffers')
elseif phase == 'exit-write' then
  assert(W.open(root .. '/C', { startup = true }))
  vim.cmd('edit ' .. vim.fn.fnameescape(root .. '/C/exit.txt'))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'draft saved by exit hook' })
  vim.cmd('qa!') -- Deliberately no explicit save, timer or stop before shutdown.
elseif phase == 'exit-read' then
  assert(W.open(root .. '/C', { startup = true }))
  check(text(named(root .. '/C/exit.txt')) == 'draft saved by exit hook', 'exit hook preserves last edits without an explicit checkpoint')
elseif phase == 'legacy' then
  assert(W.open(root .. '/D', { startup = true }))
  check(named(root .. '/D/old.txt') > 0 and text(named(root .. '/D/old.txt')) == 'old project', 'previous persistence sessions import their open files')
  check(vim.g.workspace_should_not_run == nil, 'legacy migration never executes session Vimscript')
elseif phase == 'headless' then
  vim.api.nvim_exec_autocmds('VimEnter', {}); vim.wait(30)
  check(not W.ready, 'headless installer and CLI runs cannot overwrite user workspaces')
  W.stopped = true; vim.cmd('qa!')
end
assert(W.save())
W.stopped = true
vim.cmd('qa!')
