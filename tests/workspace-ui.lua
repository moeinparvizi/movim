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
  return action_state.get_current_picker(api.nvim_get_current_buf())
end
local function close() local p = picker(); actions.close(p.prompt_bufnr); vim.cmd('stopinsert'); vim.wait(30) end
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
builtin.live_grep(); p = picker(); check(p:_get_prompt() == 'external', 'real Grep restores its independent query'); close()
api.nvim_set_current_buf(source)
api.nvim_buf_set_lines(source, 0, -1, false, { 'prefix [a.b] فارسی suffix', 'next [line]' })
api.nvim_win_set_cursor(0, { 1, 7 }); vim.cmd('normal! v4l')
require('utils.scoped_find').selection(); p = picker()
check(p:_get_prompt() == '[a.b]' and W.search('grep').literal, 'Visual grep searches selected text literally')
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
for _ = 1, 3 do T.new(); vim.cmd('stopinsert'); T.close() end
check(blank_count() == before, 'repeated terminal creation leaves no extra No Name buffers')
T.new(); vim.cmd('stopinsert'); api.nvim_win_set_height(0, 12); T.hide(); T.toggle(); vim.cmd('stopinsert')
check(api.nvim_win_get_height(0) == 12, 'terminal panel restores resized height')
T.close()
require('neo-tree.command').execute({ action = 'show', position = 'left' })
assert(vim.wait(1500, function() return treewin() ~= nil end))
api.nvim_set_current_win(treewin())
assert(W.open(root .. '/B')); assert(W.open(root .. '/A'))
assert(vim.wait(1500, function() return treewin() ~= nil end))
check(treewin() and api.nvim_win_get_width(treewin()) == 47, 'project switch from explorer restores visible sidebar and width')
require('neo-tree.command').execute({ action = 'close' })
local F = require('utils.find_panel'); F.open()
api.nvim_buf_set_lines(0, 0, -1, false, { 'remember find' }); F.close(); F.open()
check(api.nvim_buf_get_lines(0, 0, 1, false)[1] == 'remember find', 'buffer Find restores previous query')
F.close(); vim.cmd('stopinsert')
check(vim.v.errmsg == '', 'full editor integration has no Neovim errors: ' .. vim.v.errmsg)
W.stopped = true
print('PASS workspace UI integration with real Telescope, Neo-tree and terminal jobs')
vim.cmd('qa!')
