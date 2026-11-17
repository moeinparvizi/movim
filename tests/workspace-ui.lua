local root = vim.env.MOVIM_WORKSPACE_TEST_DIR:gsub('\\', '/')
local api = vim.api
vim.o.columns, vim.o.lines = 180, 48
local W = require('utils.workspace')
W.setup({ directory = root .. '/ui-state', auto_restore = false })
assert(W.open(root .. '/A', { startup = true }))
vim.cmd('edit ' .. vim.fn.fnameescape(root .. '/A/one.txt'))
local source = api.nvim_get_current_buf()
local function check(value, message) assert(value, message); print('PASS ' .. message) end
local builtin = require('telescope.builtin')
-- Load through Lazy so the actual configured picker wrappers and keymaps run.
require('lazy').load({ plugins = { 'telescope.nvim' } })
local action_state, actions = require('telescope.actions.state'), require('telescope.actions')
local function picker()
  assert(vim.wait(1500, function() return vim.bo.filetype == 'TelescopePrompt' end), 'Picker did not open')
  api.nvim_feedkeys('', 'x', false) -- Consume Telescope's queued Insert-mode keys.
  vim.wait(20) -- Allow the shared input controls to attach to overriding builtins.
  return action_state.get_current_picker(api.nvim_get_current_buf())
end
local function close() local p = picker(); actions.close(p.prompt_bufnr); vim.cmd('stopinsert'); vim.wait(30) end
local function clear_picker()
  local p = picker()
  local key
  for _, mapping in ipairs(api.nvim_buf_get_keymap(p.prompt_bufnr, 'i')) do
    if mapping.lhs:lower() == '<c-u>' then key = mapping.callback end
  end
  assert(key, 'Clear search mapping missing'); key(); vim.wait(50)
  check(p:_get_prompt() == '', 'Ctrl+U clears the whole picker query')
end
builtin.find_files(); local p = picker(); p:set_prompt('one'); vim.wait(30); close()
builtin.find_files(); p = picker()
check(p:_get_prompt() == 'one', 'real Find Files reopens with previous query')
local input = vim.ui.input
vim.ui.input = function(_, callback) callback('*.lock, ignored/**') end
local scope_key
for _, mapping in ipairs(api.nvim_buf_get_keymap(p.prompt_bufnr, 'i')) do
  if mapping.lhs:lower() == '<c-x>' then scope_key = mapping.callback end
end
assert(scope_key, 'Exclude control missing'); scope_key()
vim.wait(100); vim.ui.input = input; p = picker()
check(p:_get_prompt() == 'one' and #W.search('files').exclude == 2, 'Ctrl+X preserves query and saves exclusions')
close(); builtin.find_files(); p = picker()
check(#W.search('files').exclude == 2 and p:_get_prompt() == 'one', 'reopened picker retains exclusions')
vim.ui.input = function(_, callback) callback(root .. '/A/src') end
for _, mapping in ipairs(api.nvim_buf_get_keymap(p.prompt_bufnr, 'i')) do
  if mapping.lhs:lower() == '<c-d>' then mapping.callback(); break end
end
vim.wait(100); vim.ui.input = input; p = picker()
check(vim.fs.normalize(p.cwd):gsub('/$', '') == root .. '/A/src', 'Ctrl+D saves the search folder')
close()
builtin.live_grep(); p = picker(); p:set_prompt('external'); vim.wait(30); close()
builtin.live_grep(); p = picker(); check(p:_get_prompt() == 'external', 'real Grep restores its independent query')
clear_picker(); close(); builtin.live_grep(); p = picker()
check(p:_get_prompt() == '', 'cleared Grep query stays empty after reopening'); close()
builtin.find_files(); p = picker(); clear_picker(); close()
builtin.current_buffer_fuzzy_find(); p = picker(); p:set_prompt('disk'); clear_picker(); close()
api.nvim_set_current_buf(source)
api.nvim_buf_set_lines(source, 0, -1, false, { 'prefix [a.b] فارسی suffix', 'next [line]' })
api.nvim_win_set_cursor(0, { 1, 7 }); vim.cmd('normal! v4l')
require('utils.scoped_find').selection(); p = picker()
check(p:_get_prompt() == '[a.b]' and W.search('grep').literal, 'Visual grep searches selected text literally')
close(); api.nvim_set_current_buf(source); api.nvim_win_set_cursor(0, { 1, 7 }); vim.cmd('normal! v4l')
require('utils.scoped_find').selection('files'); p = picker()
check(p:_get_prompt() == '[a.b]', 'Visual Find Files starts with the selected text')
close(); api.nvim_set_current_buf(source); api.nvim_win_set_cursor(0, { 1, 7 }); vim.cmd('normal! v4l')
require('utils.scoped_find').selection('buffer')
check(api.nvim_buf_get_lines(0, 0, 1, false)[1] == '[a.b]', 'Visual Find in current file starts with selected literal text')
require('utils.find_panel').close(); vim.cmd('stopinsert')
builtin.live_grep(); p = picker()
close(); api.nvim_set_current_buf(source); api.nvim_win_set_cursor(0, { 1, 13 }); vim.cmd('normal! v4l')
require('utils.scoped_find').selection(); p = picker()
check(p:_get_prompt() == 'فارسی', 'Visual grep preserves complete Unicode selection: ' .. p:_get_prompt())
close(); api.nvim_set_current_buf(source); vim.cmd('normal! ggVj')
require('utils.scoped_find').selection(); p = picker()
check(W.search('grep').multiline and p:_get_prompt():find('\\n', 1, true), 'multiline Visual grep keeps escaped newline')
close()
require('neo-tree.command').execute({ action = 'show', position = 'left' })
local function treewin()
  for _, win in ipairs(api.nvim_list_wins()) do if vim.bo[api.nvim_win_get_buf(win)].filetype == 'neo-tree' then return win end end
end
assert(vim.wait(1500, function() return treewin() ~= nil end))
api.nvim_win_set_width(treewin(), 47); W.capture_sizes()
require('neo-tree.command').execute({ action = 'close' })
require('neo-tree.command').execute({ action = 'show', position = 'left' })
assert(vim.wait(1500, function() return treewin() ~= nil end))
check(api.nvim_win_get_width(treewin()) == 47, 'Neo-tree reopens at the user-selected width')
local filters = require('utils.explorer_filter')
local input_before = vim.ui.input
vim.ui.input = function(_, callback) callback('two.txt, *.log') end
filters.edit(); vim.ui.input = input_before; vim.wait(250)
local tree_state = require('neo-tree.sources.manager').get_state('filesystem')
check(#W.preference('explorer_hidden', {}) == 2, 'Neo-tree saves custom hidden names and globs')
local rendered = table.concat(api.nvim_buf_get_lines(api.nvim_win_get_buf(treewin()), 0, -1, false), '\n')
check(not rendered:find('two.txt', 1, true), 'Neo-tree actually hides excluded files')
require('neo-tree.command').execute({ action = 'close' })
local function blank_count()
  local count = 0
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and vim.bo[buf].buftype == '' and api.nvim_buf_get_name(buf) == '' then count = count + 1 end
  end
  return count
end
local before = blank_count()
local T = require('utils.terminal_panel')
for _ = 1, 3 do
  T.new(); vim.cmd('stopinsert')
  check(vim.wo.winbar:find('@ 1 ', 1, true) ~= nil, 'first terminal reuses display number 1 after closing')
  local terminal = api.nvim_get_current_buf(); T.hide(); T.toggle(); vim.cmd('stopinsert')
  check(api.nvim_get_current_buf() == terminal, 'hiding and reopening reuses the original shell')
  T.close()
end
check(blank_count() == before, 'repeated terminal creation leaves no extra No Name buffers')
vim.fn.mkdir(root .. '/A/.vscode', 'p')
vim.fn.writefile({ vim.json.encode({ version = '2.0.0', tasks = { { label = 'Smoke', type = 'process', command = vim.fn.exepath('node'), args = { '-e', "require('fs').writeFileSync('task-ran.txt', 'movim-task-ok')" } } } }) }, root .. '/A/.vscode/tasks.json')
api.nvim_set_current_buf(source)
local tasks = require('utils.tasks'); tasks.toggle()
local task_buf, task_win = api.nvim_get_current_buf(), api.nvim_get_current_win()
local lines = api.nvim_buf_get_lines(task_buf, 0, -1, false)
for row, line in ipairs(lines) do if line:find('Smoke', 1, true) then api.nvim_win_set_cursor(task_win, { row, 0 }); break end end
local run_task
for _, mapping in ipairs(api.nvim_buf_get_keymap(task_buf, 'n')) do if mapping.lhs == '<CR>' then run_task = mapping.callback end end
assert(run_task); run_task(); vim.cmd('stopinsert')
local output_buf, output_win = api.nvim_get_current_buf(), api.nvim_get_current_win()
assert(vim.wait(3000, function() return vim.fn.filereadable(root .. '/A/task-ran.txt') == 1 end), 'Task did not execute in selected project')
check(vim.bo[output_buf].buftype == 'terminal' and vim.b[output_buf].terminal_job_id ~= nil, 'task output uses a real terminal job')
check(blank_count() == before, 'real project task runs without creating a No Name buffer')
api.nvim_win_close(output_win, true); api.nvim_set_current_win(task_win); tasks.toggle()
T.new(); vim.cmd('stopinsert'); api.nvim_win_set_height(0, 12); T.hide(); T.toggle(); vim.cmd('stopinsert')
check(api.nvim_win_get_height(0) == 12, 'terminal panel restores resized height')
T.close()
T.new(); vim.cmd('stopinsert'); local project_a_terminal = api.nvim_get_current_buf()
assert(W.open(root .. '/B')); T.toggle(); vim.cmd('stopinsert')
check(api.nvim_get_current_buf() ~= project_a_terminal and api.nvim_buf_get_name(0):gsub('\\', '/'):find('/B', 1, true), 'new project opens its own terminal instead of previous project shell')
T.close(); assert(W.open(root .. '/A')); T.toggle(); vim.cmd('stopinsert')
check(api.nvim_get_current_buf() == project_a_terminal, 'returning to a project reuses its running terminal')
T.close()
require('neo-tree.command').execute({ action = 'show', position = 'left' })
assert(vim.wait(1500, function() return treewin() ~= nil end))
api.nvim_set_current_win(treewin())
assert(W.open(root .. '/B')); assert(W.open(root .. '/A'))
assert(vim.wait(1500, function() return treewin() ~= nil end))
check(treewin() and api.nvim_win_get_width(treewin()) == 47, 'project switch from explorer restores visible sidebar and width')
check(#W.preference('explorer_hidden', {}) == 2, 'hidden explorer entries survive switching workspaces')
vim.wait(250) -- Finish asynchronous filesystem rendering before closing the sidebar.
require('neo-tree.command').execute({ action = 'close' })
local F = require('utils.find_panel'); F.open()
api.nvim_buf_set_lines(0, 0, -1, false, { 'remember find' }); F.close(); F.open()
check(api.nvim_buf_get_lines(0, 0, 1, false)[1] == 'remember find', 'buffer Find restores previous query')
local find_buf = api.nvim_get_current_buf()
for _, mapping in ipairs(api.nvim_buf_get_keymap(find_buf, 'i')) do if mapping.lhs:lower() == '<c-u>' then mapping.callback(); break end end
check(api.nvim_buf_get_lines(find_buf, 0, 1, false)[1] == '', 'buffer Find has the same one-key clear action')
api.nvim_buf_set_lines(find_buf, 0, -1, false, { 'click to clear' })
local clear_win
for _, win in ipairs(api.nvim_list_wins()) do
  if api.nvim_win_get_config(win).win == api.nvim_get_current_win() and api.nvim_win_get_width(win) == 3 then clear_win = win end
end
assert(clear_win, 'Clickable clear button missing')
api.nvim_set_current_win(clear_win); vim.wait(60)
check(api.nvim_get_current_buf() == find_buf and api.nvim_buf_get_lines(find_buf, 0, 1, false)[1] == '', 'clicking clear empties Find and returns focus to its input')
F.close(); vim.cmd('stopinsert')
for _, dir in ipairs({ 'A', 'B' }) do
  local result = vim.system({ 'git', 'init', root .. '/' .. dir }, { text = true }):wait(); assert(result.code == 0, result.stderr)
end
assert(W.open(root)); local cwd_before = vim.fn.getcwd()
local select_before, selected, cancelled = vim.ui.select, nil, false
local notify_before, git_notice = vim.notify, ''
vim.notify = function(message) git_notice = tostring(message) end
vim.ui.select = function(items, _, callback)
  check(vim.tbl_contains(items, root .. '/A') and vim.tbl_contains(items, root .. '/B'), 'Git picker discovers both repositories in parent workspace')
  callback(root .. '/B')
end
require('utils.git_project').choose(function(path) selected = vim.fs.normalize(path) end)
assert(vim.wait(12000, function() return selected ~= nil end), 'Git selection did not finish: ' .. git_notice)
check(selected == root .. '/B' and vim.fn.getcwd() == cwd_before, 'Git selection targets chosen repository without changing workspace cwd')
local git_status, git_options = builtin.git_status, nil
builtin.git_status = function(options) git_options = options end
require('utils.git_project').telescope('git_status')
assert(vim.wait(12000, function() return git_options ~= nil end), 'Git status did not finish: ' .. git_notice); builtin.git_status = git_status
check(vim.fs.normalize(git_options.cwd):gsub('/$', '') == root .. '/B', 'Git status receives the chosen child repository')
vim.ui.select = function(_, _, callback) callback(nil); cancelled = true end
require('utils.git_project').choose(function() error('Cancelled Git picker opened a repository') end)
assert(vim.wait(3000, function() return cancelled end)); vim.ui.select = select_before
vim.notify = notify_before
-- File-tab close callbacks must preserve editor windows and show the dashboard.
assert(W.open(root .. '/A'))
require('neo-tree.command').execute({ action = 'show', position = 'left' })
assert(vim.wait(1500, function() return treewin() ~= nil end)); vim.wait(250)
local opts = require('bufferline.config').options
check(type(opts.close_command) == 'function' and type(opts.right_mouse_command) == 'function', 'tab mouse buttons use safe close callbacks')
local protected = api.nvim_create_buf(true, false)
api.nvim_buf_set_lines(protected, 0, -1, false, { 'keep this draft' })
local confirm = vim.fn.confirm
vim.fn.confirm = function() return 3 end; opts.close_command(protected)
check(api.nvim_buf_is_valid(protected) and vim.bo[protected].modified, 'cancelling tab close preserves unsaved text')
vim.fn.confirm = function() return 2 end; opts.close_command(protected); vim.fn.confirm = confirm
check(not api.nvim_buf_is_valid(protected), 'explicit discard closes only the selected draft')
for _, buf in ipairs(api.nvim_list_bufs()) do
  if vim.bo[buf].buflisted and vim.bo[buf].buftype == '' then
    vim.bo[buf].modified = false; opts.close_command(buf)
  end
end
local dashboard
for _, win in ipairs(api.nvim_list_wins()) do if vim.bo[api.nvim_win_get_buf(win)].filetype == 'dashboard' then dashboard = win end end
check(dashboard ~= nil and treewin() ~= nil, 'closing last file tab keeps explorer and returns to startup dashboard')
api.nvim_set_current_win(dashboard)
check(vim.v.errmsg == '', 'full editor integration has no Neovim errors: ' .. vim.v.errmsg)
W.stopped = true
print('PASS workspace UI integration with real Telescope, Neo-tree and terminal jobs')
vim.cmd('qa!')
