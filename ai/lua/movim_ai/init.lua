local M = {}
local editor, sessions, ui = require('movim_ai.editor'), require('movim_ai.sessions'), require('movim_ai.ui')
local function safe(fn)
  return function(...)
    local ok, err = pcall(fn, ...)
    if not ok then vim.notify(tostring(err), vim.log.levels.ERROR, { title = 'AI Panel' }) end
  end
end
local function source()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype == '' then ui.source = buf else buf = ui.source end
  assert(buf and vim.api.nvim_buf_is_valid(buf), 'Focus a source file first')
  return buf
end
function M.prompt(snapshot, new_tab)
  -- Capture before the async input dialog, and revalidate before submitting.
  local target
  if not new_tab then target = sessions.current() end
  vim.ui.input({ prompt = snapshot and 'AI change request: ' or 'AI message: ' }, safe(function(prompt)
    if not prompt or not prompt:match('%S') then return end
    if target then assert(vim.tbl_contains(sessions.tabs, target), 'The target AI tab was closed; open a new prompt') end
    local tab = target or sessions.new('Selection ' .. vim.fn.fnamemodify(snapshot.path, ':t'))
    sessions.send(tab, prompt, snapshot, M.config)
    ui.open()
  end))
end
function M.attach(buf, new_tab)
  local s = editor.snapshot(buf)
  local ok, err = require('movim_ai.context').check(s, M.config); assert(ok, err)
  sessions.attach(new_tab and sessions.new(vim.fn.fnamemodify(s.path, ':t')) or sessions.current(), s)
  ui.open()
end
function M.key()
  local name = M.config.api_key_env
  assert(name:match('^[A-Z][A-Z0-9_]*$'), 'Invalid API key environment variable name')
  for _, tab in ipairs(sessions.tabs) do
    assert(tab.status ~= 'processing', 'Wait or cancel running requests before changing the API key')
  end
  -- inputsecret bypasses UI plugins that might show or retain ordinary input.
  vim.fn.inputsave()
  local ok, value = pcall(vim.fn.inputsecret, 'API key (hidden; this session only): ')
  vim.fn.inputrestore()
  if not ok or not value or value == '' then return end
  assert(not value:find('%s'), 'API keys cannot contain whitespace')
  vim.env[name] = value
  for _, tab in ipairs(sessions.tabs) do
    if tab.client then tab.client:close(); tab.client = nil end
  end
  vim.notify('API key ready for this session. Use :AIChat to send a message. The key was not saved to disk.')
end
function M.configure()
  local fields = {
    { 'base_url', 'OpenAI-compatible base URL (HTTPS, no key): ' },
    { 'model', 'Exact model ID (from your provider): ' },
    { 'context_window', 'Verified model context size in tokens: ' },
    { 'api_key_env', 'API key environment variable name: ' },
  }
  local values = {}
  local function step(index)
    if index > #fields then
      assert(tonumber(values.context_window) and tonumber(values.context_window) >= 8192, 'Context window must be at least 8192')
      values.context_window = tonumber(values.context_window)
      assert(values.api_key_env:match('^[A-Z][A-Z0-9_]*$'), 'Enter an environment variable name, not a key')
      assert(not values.base_url:find('@', 1, true) and not values.base_url:find('?', 1, true), 'Do not embed credentials in the URL')
      values.provider = 'movim-custom'
      vim.fn.mkdir(vim.fn.fnamemodify(M.settings_path, ':h'), 'p')
      vim.fn.writefile({ vim.json.encode(values) }, M.settings_path)
      M.config = vim.tbl_deep_extend('force', M.config, values)
      vim.notify('AI provider saved. Use :AIKey to enter or replace your key without restarting.')
      if not vim.env[values.api_key_env] or vim.env[values.api_key_env] == '' then M.key() end
      return
    end
    local field = fields[index]
    vim.ui.input({ prompt = field[2], default = tostring(M.config[field[1]]) }, safe(function(value)
      if value == nil then return end
      values[field[1]] = value; step(index + 1)
    end))
  end
  step(1)
end
function M.setup(options)
  if M.config then return end
  local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
  M.settings_path = vim.fn.stdpath('state') .. '/movim-ai/provider.json'
  local saved = {}
  if vim.fn.filereadable(M.settings_path) == 1 then
    local ok, value = pcall(vim.json.decode, table.concat(vim.fn.readfile(M.settings_path), '\n'))
    if ok and type(value) == 'table' then
      for _, key in ipairs({ 'provider', 'base_url', 'model', 'context_window', 'api_key_env' }) do saved[key] = value[key] end
    end
  end
  M.config = vim.tbl_deep_extend('force', {
    root = root, node = 'node', provider = 'movim-custom', model = '', base_url = '', api = 'openai-completions',
    api_key_env = 'MOVIM_AI_API_KEY', context_window = 32768, output_tokens = 4096, timeout_ms = 120000,
    sensitive_policy = 'deny', sensitive_patterns = { '/%.env', '^%.env', '%.pem$', '%.key$', '/id_rsa', '/id_ed25519', '/credentials', '/secrets?[%./]', '/%.ssh/', '/auth%.json$' },
    keys = { toggle = '<leader>aa', selection = '<leader>ae', attach = '<leader>af' },
    panel_keys = { chat = 'i', new = 'n', select = 't', rename = 'r', close_tab = 'x', cancel = '<C-c>', preview = 'd', apply = 'a', reject = 'R', hide = 'q' },
  }, saved, options or vim.g.movim_ai or {})
  local commands = {}
  commands.AIPanel = function() ui.toggle() end
  commands.AIChat = function() M.prompt(nil, false) end
  commands.AINew = function() sessions.new(); ui.open() end
  commands.AISelect = function()
    vim.ui.select(sessions.tabs, { prompt = 'AI tab', format_item = function(t) return t.name .. ' [' .. t.status .. ']' end }, function(t)
      if t then sessions.selected = t.id; ui.open(); ui.render() end
    end)
  end
  commands.AIRename = function()
    local t = sessions.current()
    vim.ui.input({ prompt = 'Tab name: ', default = t.name }, function(name)
      if name and name:match('%S') then t.name = name:gsub('[\r\n]', ' '); ui.render() end
    end)
  end
  commands.AICloseTab = function()
    local t = sessions.current()
    if t.status == 'processing' then
      vim.ui.select({ 'Keep running', 'Cancel request and close tab' }, { prompt = 'This tab is processing' }, function(choice)
        if choice == 'Cancel request and close tab' then sessions.close(t); ui.render() end
      end)
    else sessions.close(t); ui.render() end
  end
  commands.AICancel = function() sessions.cancel(sessions.current()) end
  commands.AIAttach = function(opts) M.attach(source(), opts and opts.bang) end
  commands.AIFile = function(opts)
    local path = opts.args
    if path == '' then
      vim.ui.input({ prompt = 'File to attach: ', completion = 'file' }, safe(function(value)
        if value and value ~= '' then commands.AIFile({ args = value, bang = opts.bang }) end
      end)); return
    end
    path = vim.fn.fnamemodify(path, ':p')
    assert(vim.fn.filereadable(path) == 1 or vim.fn.bufnr(path) ~= -1, 'File does not exist')
    local buf = vim.fn.bufadd(path); vim.fn.bufload(buf); M.attach(buf, opts.bang)
  end
  commands.AIRefresh = function()
    local t = sessions.current(); assert(t.status ~= 'processing', 'Wait or cancel before refreshing context')
    for i, s in ipairs(t.attachments) do t.attachments[i] = editor.snapshot(s.buf) end
    for buf in pairs(t.contexts) do t.contexts[buf] = editor.snapshot(buf) end
    ui.render()
  end
  commands.AIRemove = function()
    local t = sessions.current()
    vim.ui.select(t.attachments, { prompt = 'Remove attachment', format_item = function(s) return s.path end }, function(s)
      if s then
        for i, value in ipairs(t.attachments) do if value == s then table.remove(t.attachments, i); break end end
        t.contexts[s.buf] = nil
        -- Remove old model-side copies too; visible transcript stays available.
        if t.client then t.client:cancel(); t.client = nil end
        if t.status == 'processing' then sessions.cancel(t) end
        t.history[#t.history + 1] = { role = 'system', text = 'Attachment removed. The next request starts a fresh Pi session.' }
        ui.render()
      end
    end)
  end
  commands.AIPreview = function() ui.preview(sessions.current().request) end
  commands.AIApply = function() sessions.resolve(sessions.current(), 'apply') end
  commands.AIReject = function() sessions.resolve(sessions.current(), 'reject') end
  commands.AIRevise = function()
    local r = sessions.current().request; assert(r and r.status == 'review', 'No proposal to revise')
    M.prompt(r.snapshot, false)
  end
  commands.AIRerun = function()
    local r = sessions.current().request; assert(r and r.snapshot, 'No selection request in this tab')
    vim.notify('Return to the source, select the intended range again, and press ' .. M.config.keys.selection .. '. Old line numbers are never reused after edits.')
    if vim.api.nvim_buf_is_valid(r.snapshot.buf) then vim.cmd('wincmd p'); vim.api.nvim_set_current_buf(r.snapshot.buf) end
  end
  commands.AIConfigure = M.configure
  commands.AIKey = M.key
  commands.AIMove = function(opts) ui.move(opts.args) end
  commands.AIResize = function(opts) ui.resize(opts.args) end
  for name, action in pairs(commands) do
    local opts = { desc = 'AI Panel: ' .. name, force = true }
    if name == 'AIMove' or name == 'AIResize' then opts.nargs = 1 end
    if name == 'AIAttach' or name == 'AIFile' then opts.bang = true end
    if name == 'AIFile' then opts.nargs = '?'; opts.complete = 'file' end
    if name == 'AIMove' then opts.complete = function() return { 'left', 'right', 'top', 'bottom' } end end
    vim.api.nvim_create_user_command(name, safe(action), opts)
  end
  ui.actions = { chat = safe(commands.AIChat), new = safe(commands.AINew), select = safe(commands.AISelect), rename = safe(commands.AIRename),
    close_tab = safe(commands.AICloseTab), cancel = safe(commands.AICancel), preview = safe(commands.AIPreview), apply = safe(commands.AIApply), reject = safe(commands.AIReject), hide = ui.hide }
  ui.config = M.config; sessions.on_change = ui.render
  local keys = M.config.keys
  if keys.toggle then vim.keymap.set('n', keys.toggle, safe(commands.AIPanel), { desc = 'AI Panel' }) end
  if keys.attach then vim.keymap.set('n', keys.attach, safe(commands.AIAttach), { desc = 'AI: attach buffer' }) end
  if keys.selection then vim.keymap.set('x', keys.selection, safe(function()
    local s = editor.visual()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'nx', false)
    M.prompt(s, true)
  end), { desc = 'AI: propose selection change' }) end
  vim.api.nvim_create_user_command('AISelection', safe(function(opts)
    M.prompt(opts.range > 0 and editor.marked() or editor.visual(), true)
  end), { desc = 'AI: selected text', force = true, range = true })
  local group = vim.api.nvim_create_augroup('MovimAIPanel', { clear = true })
  vim.api.nvim_create_autocmd('VimLeavePre', { group = group, callback = sessions.shutdown })
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'BufEnter' }, { group = group, callback = function()
    if vim.bo.buftype ~= '' then return end
    ui.source = vim.api.nvim_get_current_buf()
    if ui.visible() then ui.render() end
  end })
end
return M
