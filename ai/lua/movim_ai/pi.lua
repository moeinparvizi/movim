local M = { version = '0.73.1' }
local uv = vim.uv
function M.decoder(on_message, on_error)
  local pending, failed = '', false
  return function(chunk)
    if failed then return end
    if not chunk then
      if pending ~= '' then failed = true; on_error('Incomplete JSONL record at EOF') end
      return
    end
    pending = pending .. chunk
    if #pending > 8 * 1024 * 1024 then failed = true; on_error('RPC record too large'); return end
    while true do
      local ending = pending:find('\n', 1, true)
      if not ending then return end
      local line = pending:sub(1, ending - 1):gsub('\r$', '')
      pending = pending:sub(ending + 1)
      if line ~= '' then
        local ok, value = pcall(vim.json.decode, line)
        if not ok or type(value) ~= 'table' then failed = true; on_error('Invalid JSONL from Pi'); return end
        on_message(value)
      end
    end
  end
end
function M.new(config, tab_id)
  local client = { pending = {}, sequence = 0, closed = false, history = '', window = config.context_window }
  local root = config.root
  local cli = root .. '/runtime/node_modules/@mariozechner/pi-coding-agent/dist/cli.js'
  local package = root .. '/runtime/node_modules/@mariozechner/pi-coding-agent/package.json'
  assert(vim.fn.filereadable(package) == 1, 'Pinned Pi runtime missing; run the AI installer first')
  assert(vim.json.decode(table.concat(vim.fn.readfile(package), '\n')).version == M.version, 'Pi version mismatch; reinstall the pinned runtime')
  assert(config.model ~= '', 'Configure a model first: :AIConfigure (or vim.g.movim_ai)')
  local folder = vim.fn.stdpath('state') .. '/movim-ai/private/' .. tostring(vim.fn.getpid()) .. '-' .. tostring(uv.hrtime()) .. '-' .. tab_id
  vim.fn.mkdir(folder .. '/work', 'p', 448)
  vim.fn.writefile({ vim.json.encode({ compaction = { enabled = false }, retry = { enabled = false }, packages = {} }) }, folder .. '/settings.json')
  if config.base_url ~= '' then
    assert(config.base_url:match('^https://') or config.base_url:match('^http://localhost[:/]') or config.base_url:match('^http://127%.0%.0%.1[:/]'), 'Use HTTPS or a loopback endpoint')
    assert(config.api_key_env:match('^[A-Z][A-Z0-9_]*$'), 'api_key_env must name an environment variable, never a shell command')
    assert(vim.env[config.api_key_env] and vim.env[config.api_key_env] ~= '', 'Enter your API key with :AIKey, or set environment variable ' .. config.api_key_env)
    local provider = { baseUrl = config.base_url, api = config.api, apiKey = config.api_key_env,
      models = { { id = config.model, name = config.model, reasoning = false, input = { 'text' },
        contextWindow = config.context_window, maxTokens = config.output_tokens, cost = { input = 0, output = 0, cacheRead = 0, cacheWrite = 0 } } } }
    vim.fn.writefile({ vim.json.encode({ providers = { [config.provider] = provider } }) }, folder .. '/models.json')
  end
  local input, output, errors = uv.new_pipe(false), uv.new_pipe(false), uv.new_pipe(false)
  local timer = uv.new_timer()
  local function fail(reason)
    if client.closed then return end
    local key = vim.env[config.api_key_env]
    if key and key ~= '' then reason = tostring(reason):gsub(key:gsub('([^%w])', '%%%1'), '[redacted]') end
    if client.active then local callback = client.active; client.active = nil; callback('error', reason) end
    client:close()
  end
  local function emit(value)
    if client.closed then return end
    if value.type == 'response' then
      local callback = client.pending[value.id]
      client.pending[value.id] = nil
      if callback then callback(value.success, value.data, value.error) end
    elseif value.type == 'tool_execution_start' then
      fail('Unexpected tool execution; session stopped')
    elseif value.type == 'message_update' and client.active then
      local event = value.assistantMessageEvent or {}
      if event.type == 'text_delta' then client.active('delta', event.delta or '') end
    elseif value.type == 'message_end' and client.active then
      local message = value.message or {}
      if message.role == 'assistant' and (message.stopReason == 'error' or message.stopReason == 'aborted') then
        fail(message.errorMessage or message.stopReason)
      end
    elseif value.type == 'agent_end' and client.active then
      local messages = value.messages or {}
      local answer
      for _, message in ipairs(messages) do
        if message.role == 'assistant' then
          if message.stopReason == 'error' or message.stopReason == 'aborted' then fail(message.errorMessage or message.stopReason); return end
          local parts = {}
          for _, content in ipairs(message.content or {}) do
            if content.type == 'toolCall' then fail('Unexpected tool call in proposal mode'); return end
            if content.type == 'text' then parts[#parts + 1] = content.text end
          end
          answer = table.concat(parts)
        end
      end
      timer:stop()
      local callback = client.active; client.active = nil
      if not answer then callback('error', 'Pi ended without an assistant response') else
        client.history = client.history .. '\n' .. answer
        callback('done', answer)
      end
    end
  end
  local decode = M.decoder(function(message) vim.schedule(function() emit(message) end) end,
    function(reason) vim.schedule(function() fail(reason) end) end)
  local env = vim.fn.environ()
  env.PI_CODING_AGENT_DIR = folder
  -- Disable Node startup hooks inherited from unrelated developer shells.
  env.NODE_OPTIONS, env.NODE_PATH = nil, nil
  local environment = {}
  for key, value in pairs(env) do environment[#environment + 1] = key .. '=' .. value end
  local argv = { cli, '--mode', 'rpc', '--no-session', '--no-tools', '--no-extensions', '--no-skills',
    '--no-prompt-templates', '--no-themes', '--no-context-files', '--provider', config.provider,
    '--model', config.model, '--system-prompt', require('movim_ai.context').system }
  client.command = vim.deepcopy(argv)
  local handle, spawn_error
  handle, spawn_error = uv.spawn(config.node, { args = argv, cwd = folder .. '/work', env = environment,
    stdio = { input, output, errors }, hide = true }, function(code)
      vim.schedule(function() if not client.closed then fail('Pi process exited (' .. tostring(code) .. ')') end end)
      if handle and not handle:is_closing() then handle:close() end
    end)
  function client:close()
    if self.closed then return end
    self.closed = true
    self.active, self.pending = nil, {}
    timer:stop(); timer:close()
    for _, pipe in ipairs({ input, output, errors }) do if not pipe:is_closing() then pipe:close() end end
    if handle and not handle:is_closing() then handle:kill('sigterm') end
  end
  if not handle then client:close(); error('Could not start Node/Pi: ' .. tostring(spawn_error)) end
  output:read_start(function(err, data)
    if err then vim.schedule(function() fail('RPC read failed') end) else decode(data) end
  end)
  errors:read_start(function(err, data)
    -- Do not echo stderr: provider errors may contain authentication material.
    if err then vim.schedule(function() fail('Pi stderr read failed') end) end
  end)
  function client:rpc(kind, data, callback)
    if self.closed then if callback then callback(false, nil, 'Pi session closed') end; return end
    self.sequence = self.sequence + 1
    local id = 'rpc-' .. self.sequence
    local command = vim.tbl_extend('force', data or {}, { type = kind, id = id })
    self.pending[id] = callback or function() end
    input:write(vim.json.encode(command) .. '\n', function(err)
      if err then vim.schedule(function() fail('Cannot write to Pi RPC') end) end
    end)
  end
  function client:send(message, callback)
    assert(not self.active and not self.closed, 'Pi session is busy or closed')
    self.active = callback
    timer:start(config.timeout_ms, 0, function() vim.schedule(function() fail('Request timed out; retry explicitly') end) end)
    self:rpc('get_state', {}, function(ok, state, err)
      if not ok then fail(err or 'Cannot read Pi state'); return end
      local window = math.min(config.context_window, state and state.model and state.model.contextWindow or 0)
      local output_reserve = math.max(config.output_tokens, state and state.model and state.model.maxTokens or 0)
      self:rpc('get_messages', {}, function(messages_ok, data, messages_error)
      if not messages_ok then fail(messages_error or 'Cannot measure Pi conversation context'); return end
      -- Count the actual RPC history, including thinking and message framing.
      local fits, bound = require('movim_ai.context').fits(message, vim.json.encode(data and data.messages or {}), window, output_reserve)
      if not fits then
        timer:stop(); self.active = nil
        callback('error', ('Context exceeds safe budget (%d > %d). Remove attachments, start a fresh tab, or configure a larger model. Nothing was sent.'):format(bound, window)); return
      end
      self:rpc('set_auto_compaction', { enabled = false }, function(compact_ok)
        if not compact_ok then fail('Could not disable context compaction'); return end
        self.history = self.history .. '\n' .. message
        self:rpc('prompt', { message = message }, function(accepted, _, reason)
          if not accepted then fail(reason or 'Pi rejected request') end
        end)
      end)
      end)
    end)
  end
  function client:cancel()
    self:rpc('abort', {})
    self:close() -- kill fences all late events; history stays visible in the tab.
  end
  return client
end
return M
