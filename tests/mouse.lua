-- An attached UI exercises real mouse coordinates and inline virtual text.
local repo = vim.fn.getcwd()
local scratch = assert(vim.env.MOVIM_WORKSPACE_TEST_DIR):gsub('\\', '/') .. '/mouse'
vim.fn.mkdir(scratch, 'p')
local stderr = {}
local channel = vim.fn.jobstart({ vim.v.progpath, '--embed', '--headless', '-u', 'NONE' }, {
  rpc = true, cwd = scratch, on_stderr = function(_, lines) vim.list_extend(stderr, lines) end,
})
assert(channel > 0)
local function request(method, ...) return vim.rpcrequest(channel, method, ...) end
local function lua(code, ...) return request('nvim_exec_lua', code, { ... }) end
local function check(value, message) assert(value, message); print('PASS ' .. message) end
local function mouse(row, col)
  request('nvim_input_mouse', 'left', 'press', '', 0, row - 1, col - 1)
  request('nvim_input_mouse', 'left', 'release', '', 0, row - 1, col - 1)
  vim.wait(60)
end
local ok, err = pcall(function()
  request('nvim_ui_attach', 120, 35, { rgb = true })
  lua([[
    local repo = ...
    vim.opt.rtp:prepend(repo)
    vim.o.mouse, vim.o.showtabline = 'a', 2
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'const فارسی = 1; const second = 2;' })
    vim.bo.filetype = 'typescript'
    local H = require('utils.inlay_hints'); H.setup()
    local hints = {
      { position = { line = 0, character = 11 }, kind = 1, label = { { value = ': { nested: ' }, { value = 'ReadonlyArray<string>; value: number }' } } },
      { position = { line = 0, character = 29 }, kind = 2, label = 'parameter:' },
    }
    local next_id, closing = 0, false
    vim.g.fixture_client = vim.lsp.start({
      name = 'movim-inlay-test', root_dir = vim.fn.getcwd(),
      cmd = function()
        return {
          request = function(method, _, callback)
            next_id = next_id + 1
            vim.schedule(function()
              if method == 'initialize' then callback(nil, { capabilities = { inlayHintProvider = true, textDocumentSync = 1 } })
              elseif method == 'textDocument/inlayHint' then callback(nil, vim.deepcopy(hints))
              elseif method == 'shutdown' then callback(nil, nil) end
            end)
            return true, next_id
          end,
          notify = function() return true end,
          is_closing = function() return closing end,
          terminate = function() closing = true end,
        }
      end,
      on_attach = function(client, buf) H.attach(client, buf); vim.lsp.inlay_hint.enable(true, { bufnr = buf }) end,
    })
  ]], repo)
  check(vim.wait(3000, function() return lua("return #vim.lsp.inlay_hint.get({bufnr=0}) == 2") end), 'LSP fixture supplies both type and parameter inlay hints')
  request('nvim_command', 'redraw')
  check(lua([[local h=vim.lsp.inlay_hint.get({bufnr=0}); return h[1].inlay_hint.label == ': …' and h[2].inlay_hint.label == 'parameter:']]), 'type hints collapse while parameter names remain readable')
  local position = lua([[return vim.fn.screenpos(0, 1, 17)]]) -- UTF-16 offset 11 is byte 16.
  -- Locate the rendered ellipsis directly from the attached screen.
  local hintcell = lua([[
    for row=1, vim.o.lines do for col=1, vim.o.columns do
      if vim.fn.screenstring(row,col) == '…' then return {row,col} end
    end end
  ]])
  assert(hintcell, 'Collapsed inlay hint was not rendered: ' .. vim.inspect(position))
  mouse(hintcell[1], hintcell[2])
  check(vim.wait(1000, function()
    return lua([[for _,win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(win).relative ~= '' then
        local text=table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win),0,-1,false),'\n')
        if text:find('ReadonlyArray<string>; value: number',1,true) then return true end
      end
    end return false]])
  end), 'clicking the rendered type hint shows its complete server label')
  check(lua([[return vim.api.nvim_buf_get_lines(0,0,1,false)[1] == 'const فارسی = 1; const second = 2;']]), 'expanding a hint does not change source text')
  lua([[for _,win in ipairs(vim.api.nvim_list_wins()) do if vim.api.nvim_win_get_config(win).relative ~= '' then vim.api.nvim_win_close(win,true) end end]])
  mouse(position.row, position.curscol)
  check(lua([[for _,win in ipairs(vim.api.nvim_list_wins()) do if vim.api.nvim_win_get_config(win).relative ~= '' then return false end end return true]]), 'clicking source text beside a hint keeps normal mouse behavior')
  -- Load the real distribution and click the actual tab bar, including padding.
  lua([[
    local repo = ...
    vim.lsp.stop_client(vim.g.fixture_client, true)
    vim.o.loadplugins = true
    vim.env.MYVIMRC = repo .. '/init.lua'
    dofile(repo .. '/init.lua')
    require('utils.workspace').setup({ auto_restore = false })
    assert(require('utils.workspace').open(vim.fn.getcwd(), { startup = true }))
    vim.fn.writefile({ 'alpha' }, 'alpha.txt')
    vim.fn.mkdir('nested', 'p'); vim.fn.writefile({ 'keep' }, 'nested/keep.txt')
    vim.cmd('edit alpha.txt')
    require('neo-tree.command').execute({ action = 'show', position = 'left' })
    vim.cmd('redraw')
  ]], repo)
  vim.wait(400)
  local tab = lua([[local text = {}; for col=1,vim.o.columns do text[col]=vim.fn.screenstring(1,col) end return table.concat(text)]])
  local namecol = lua([[for col=1,vim.o.columns-9 do
    local value=''; for offset=0,8 do value=value..vim.fn.screenstring(1,col+offset) end
    if value=='alpha.txt' then return col end
  end]])
  assert(type(namecol) == 'number', 'File tab did not render: ' .. tab)
  mouse(1, namecol + 2)
  mouse(1, 119)
  check(lua([[return vim.fn.filereadable('alpha.txt') == 1]]), 'clicking a file tab and empty tab-bar space never exits the editor')
  local x = lua([[for col=1,vim.o.columns do if vim.fn.screenstring(1,col)=='x' then return col end end]])
  assert(x, 'Tab close button did not render')
  -- alpha.txt itself contains x; find the close button after the file name.
  x = lua([[local start = ...; for col=start,vim.o.columns do if vim.fn.screenstring(1,col)=='x' then return col end end]], namecol + #'alpha.txt')
  assert(type(x) == 'number', 'File close button missing: ' .. tab)
  mouse(1, x)
  check(lua([[for _,win in ipairs(vim.api.nvim_list_wins()) do if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'dashboard' then return true end end return false]]), 'clicking the last file close button returns to the dashboard')
  lua([[
    assert(vim.wait(1000, function() return not require('utils.workspace').explorer_loading end), vim.inspect({loading=require('utils.workspace').explorer_loading, tree=require('neo-tree.sources.manager').get_state('filesystem').path}))
    local state = require('neo-tree.sources.manager').get_state('filesystem')
    local node = state.tree:get_node(require('neo-tree.utils').normalize_path(vim.fn.getcwd() .. '/nested'))
    assert(node, 'Nested folder missing from tree')
    if not node:is_expanded() then require('neo-tree.sources.filesystem').toggle_directory(state, node) end
    assert(vim.wait(1000, function() return node:is_expanded() end), 'Nested folder did not expand')
    for _,win in ipairs(vim.api.nvim_list_wins()) do
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype=='neo-tree' then vim.api.nvim_win_set_width(win, 47) end
    end
    assert(require('utils.workspace').save())
  ]])
  vim.fn.jobstop(channel); vim.fn.jobwait({ channel }, 2000)
  channel = vim.fn.jobstart({ vim.v.progpath, '--embed', '--headless', '-u', repo .. '/init.lua' }, { rpc = true, cwd = scratch })
  request('nvim_ui_attach', 120, 35, { rgb = true })
  local restored = vim.wait(4000, function()
    return lua([[for _,win in ipairs(vim.api.nvim_list_wins()) do
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype=='neo-tree' then return vim.api.nvim_win_get_width(win)==47 end
    end return false]])
  end)
  if not restored then print(vim.inspect(lua([[return {ready=require('utils.workspace').ready, root=require('utils.workspace').root, state=require('utils.workspace').current(), wins=vim.fn.getwininfo(), errors=vim.v.errmsg, messages=vim.api.nvim_exec2('messages',{output=true}).output}]]))) end
  check(restored, 'fresh editor process restores Explorer to the exact saved width')
  check(lua([[local state=require('neo-tree.sources.manager').get_state('filesystem')
    local node=state.tree:get_node(require('neo-tree.utils').normalize_path(vim.fn.getcwd()..'/nested'))
    return node and node:is_expanded() or false]]), 'fresh editor process restores expanded Explorer folders')
end)
pcall(vim.fn.jobstop, channel)
vim.fn.jobwait({ channel }, 2000)
assert(ok, tostring(err) .. '\n' .. table.concat(stderr, '\n'))
vim.cmd('qa!')
