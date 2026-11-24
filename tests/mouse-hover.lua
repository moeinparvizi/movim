local repo = vim.fn.getcwd():gsub('\\', '/')
local channel = vim.fn.jobstart({ vim.v.progpath, '--embed', '--headless', '-u', 'NONE' }, { rpc = true })
local function request(method, ...) return vim.rpcrequest(channel, method, ...) end
local function lua(code, ...) return request('nvim_exec_lua', code, { ... }) end
local ok, err = pcall(function()
  request('nvim_ui_attach', 100, 30, { rgb = true })
  lua([[
    vim.opt.rtp:prepend(...)
    vim.o.mouse = 'a'
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'const فارسی = callMethod(); other();' })
    require('utils.mouse_hover').setup()
    local next_id = 0
    vim.g.hover_requests = 0
    vim.g.hover_client = vim.lsp.start({
      name = 'hover-fixture', root_dir = vim.fn.getcwd(),
      cmd = function() return {
        request = function(method, params, callback)
          next_id = next_id + 1
          if method == 'initialize' then
            vim.schedule(function() callback(nil, { capabilities = { hoverProvider = true, textDocumentSync = 1 } }) end)
          elseif method == 'textDocument/hover' then
            vim.g.hover_requests = vim.g.hover_requests + 1
            vim.g.hover_position = params.position
            vim.defer_fn(function() callback(nil, { contents = { kind = 'markdown', value = '**Method documentation**\nReturns a value.' } }) end, 150)
          elseif method == 'shutdown' then vim.schedule(function() callback(nil, nil) end) end
          return true, next_id
        end,
        notify = function() return true end,
        is_closing = function() return false end,
        terminate = function() end,
      } end,
    })
    vim.cmd('redraw')
  ]], repo)
  assert(vim.wait(2000, function() return lua([[return #vim.lsp.get_clients({ bufnr = 0, method = 'textDocument/hover' }) > 0]]) end), 'hover LSP did not attach')
  local cell = lua([[local line=vim.api.nvim_get_current_line(); local col=line:find('callMethod', 1, true); return vim.fn.screenpos(0, 1, col)]])
  local before = lua([[return vim.api.nvim_win_get_cursor(0)]])
  request('nvim_input_mouse', 'move', '', '', 0, cell.row - 1, cell.col - 1)
  assert(vim.wait(3000, function() return lua([[for _, win in ipairs(vim.api.nvim_list_wins()) do
    local text=table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win),0,-1,false), '\n')
    if text:find('Method documentation', 1, true) then return true end
  end return false]]) end), 'hover documentation was not displayed')
  assert(lua([[local line=vim.api.nvim_get_current_line(); local byte=line:find('callMethod',1,true)-1
    return vim.g.hover_position.line == 0 and vim.g.hover_position.character == vim.str_utfindex(line,'utf-16',byte)]]), 'hover position must use the server encoding')
  assert(vim.deep_equal(before, lua([[return vim.api.nvim_win_get_cursor(0)]])), 'hover moved the text cursor')
  request('nvim_input_mouse', 'move', '', '', 0, cell.row, 0)
  assert(vim.wait(1500, function() return lua([[for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative ~= '' then return false end
  end return true]]) end), 'hover popup did not close when mouse moved away')
  local count = lua([[return vim.g.hover_requests]])
  request('nvim_input_mouse', 'move', '', '', 0, cell.row - 1, cell.col - 1)
  assert(vim.wait(2000, function() return lua([[return vim.g.hover_requests > ...]], count) end), 'second hover request missing')
  request('nvim_input_mouse', 'move', '', '', 0, cell.row, 0)
  vim.wait(350)
  assert(lua([[for _, win in ipairs(vim.api.nvim_list_wins()) do if vim.api.nvim_win_get_config(win).relative ~= '' then return false end end return true]]), 'late hover response reopened popup')
  request('nvim_input', 'i')
  assert(vim.wait(1000, function() return lua([[return vim.fn.mode() == 'i']]) end), 'insert mode did not start')
  request('nvim_input_mouse', 'move', '', '', 0, cell.row - 1, cell.col - 1)
  assert(vim.wait(3000, function() return lua([[for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative ~= '' then return true end end return false]]) end), 'hover in Insert mode did not show documentation')
  request('nvim_input', '\27')
  assert(vim.wait(1000, function() return lua([[return vim.fn.mode() == 'n']]) end), 'insert mode did not exit')
  local other = lua([[local original=vim.api.nvim_get_current_win(); vim.cmd('vsplit'); local other=vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(original); vim.cmd('redraw'); local line=vim.api.nvim_get_current_line()
    local col=line:find('callMethod',1,true); return { win=other, cell=vim.fn.screenpos(other,1,col), original=original }]])
  request('nvim_input_mouse', 'move', '', '', 0, 10, 0)
  vim.wait(50)
  request('nvim_input_mouse', 'move', '', '', 0, other.cell.row - 1, other.cell.col - 1)
  assert(vim.wait(3000, function() return lua([[for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative ~= '' then return true end end return false]]) end), 'hover in inactive split did not show documentation')
  assert(lua([[return vim.api.nvim_get_current_win() == ...]], other.original), 'hover changed the active split')
  print('PASS mouse hover documentation in Normal, Insert and inactive split; UTF-16 and stale response')
end)
vim.fn.jobstop(channel)
assert(ok, err)
vim.cmd('qa!')
