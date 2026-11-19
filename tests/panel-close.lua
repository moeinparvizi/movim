local repo = vim.fn.getcwd()
local child = vim.fn.jobstart({ vim.v.progpath, '--embed', '--headless', '-u', repo .. '/init.lua' }, {
  rpc = true, cwd = assert(vim.env.MOVIM_PANEL_TEST_DIR),
})
assert(child > 0)
local function request(method, ...) return vim.rpcrequest(child, method, ...) end
local function execute(code, ...) return request('nvim_exec_lua', code, { ... }) end
local ok, failure = pcall(function()
  request('nvim_ui_attach', 120, 35, { rgb = true })
  execute([[require('lazy').load({ plugins = { 'noice.nvim' } }); vim.cmd('doautocmd User VeryLazy')]])
  vim.wait(500)
  execute([[vim.cmd('tab split'); vim.t.movim_name = 'Backend'; vim.cmd('tabprevious')]])
  execute([[vim.schedule(function() require('utils.named_tabs').select() end)]])
  assert(vim.wait(3000, function() return execute([[return vim.fn.mode():find('c') ~= nil or #vim.api.nvim_list_uis() == 0]]) end), 'workspace selector did not open')
  request('nvim_input', '2\r')
  assert(vim.wait(3000, function() return execute([[return vim.t.movim_name == 'Backend']]) end), 'workspace not selected')
  vim.wait(400)
  local active = execute([[return { mode=vim.fn.mode(), wins=vim.fn.getwininfo(), messages=vim.api.nvim_exec2('messages',{output=true}).output }]])
  local floats = 0
  for _, win in ipairs(active.wins) do if win.popup == 1 then floats = floats + 1 end end
  assert(floats == 0, 'selection left a floating panel open: ' .. vim.inspect(active))
  local screen = execute([[local rows={}; for row=1,vim.o.lines do local cells={}; for col=1,vim.o.columns do cells[col]=vim.fn.screenstring(row,col) end; rows[row]=table.concat(cells) end; return table.concat(rows,'\n')]])
  assert(not screen:find('Workspace:', 1, true), 'workspace prompt remained on screen: ' .. screen)
  print('PASS workspace selector closes after selection')
  execute([[
    local workspace = require('utils.workspace')
    local initial = vim.fn.getcwd()
    local other = initial .. '/panel-project'
    vim.fn.mkdir(other, 'p')
    assert(workspace.open(other))
    vim.wait(1100)
    assert(workspace.open(initial))
    vim.schedule(function() workspace.select() end)
  ]])
  assert(vim.wait(3000, function() return execute([[return vim.fn.mode():find('c') ~= nil]]) end), 'project selector did not open')
  request('nvim_input', '2\r')
  assert(vim.wait(3000, function() return execute([[return require('utils.workspace').root:find('panel%-project') ~= nil]]) end), 'project not selected')
  vim.wait(500)
  local project_wins = execute([[return vim.fn.getwininfo()]])
  for _, win in ipairs(project_wins) do assert(win.popup ~= 1, 'project selector left a floating panel open') end
  print('PASS project selector closes after switching projects')
  execute([[vim.schedule(function() vim.ui.input({prompt='Panel name: '}, function(value) vim.g.panel_input_result=value or 'cancelled' end) end)]])
  assert(vim.wait(3000, function() return execute([[return vim.fn.mode():find('c') ~= nil]]) end), 'input did not open')
  request('nvim_input', 'example\r')
  assert(vim.wait(3000, function() return execute([[return vim.g.panel_input_result == 'example']]) end), 'input callback did not receive text')
  vim.wait(300)
  for _, win in ipairs(execute([[return vim.fn.getwininfo()]])) do assert(win.popup ~= 1, 'input left a floating panel open') end
  print('PASS input panel closes after submission')
end)
pcall(vim.fn.jobstop, child)
vim.fn.jobwait({ child }, 2000)
assert(ok, tostring(failure))
vim.cmd('qa!')
