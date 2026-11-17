-- Keep the server's complete hints; shorten only their displayed labels.
local M = {}
local records = {}
local function label(hint)
  if type(hint.label) == 'string' then return hint.label end
  local parts = {}
  for _, part in ipairs(hint.label or {}) do parts[#parts + 1] = part.value end
  return table.concat(parts)
end
local function render(record)
  local result = vim.deepcopy(record.hints)
  for _, hint in ipairs(result) do
    if hint.kind == 1 then hint.label = ': …' end
  end
  record.handler(nil, result, record.context)
end
function M.attach(client, buf)
  if not vim.tbl_contains({ 'typescript', 'typescriptreact', 'javascript', 'javascriptreact', 'vue' }, vim.bo[buf].filetype) then return end
  if not client._movim_compact_hints then
    client._movim_compact_hints = true
    local handler = client.handlers['textDocument/inlayHint'] or vim.lsp.handlers['textDocument/inlayHint']
    client.handlers['textDocument/inlayHint'] = function(err, result, context, config)
      if err or not vim.api.nvim_buf_is_valid(context.bufnr) then return handler(err, result, context, config) end
      if context.version ~= vim.lsp.util.buf_versions[context.bufnr] then return end
      records[context.bufnr] = records[context.bufnr] or {}
      local record = { hints = vim.deepcopy(result or {}), context = vim.deepcopy(context),
        handler = function(e, hints, ctx) return handler(e, hints, ctx, config) end, encoding = client.offset_encoding }
      records[context.bufnr][context.client_id] = record
      render(record)
    end
  end
  vim.keymap.set('n', '<LeftMouse>', M.mouse, { buffer = buf, expr = true, replace_keycodes = true, desc = 'Show complete type hint' })
  vim.keymap.set('n', '<leader>uI', function() M.show_line(buf, vim.api.nvim_win_get_cursor(0)[1]) end,
    { buffer = buf, desc = 'Show complete type hints on this line' })
end
local function current(buf)
  if not vim.lsp.inlay_hint.is_enabled({ bufnr = buf }) then return {} end
  local result = {}
  for id, record in pairs(records[buf] or {}) do
    local client = vim.lsp.get_client_by_id(id)
    if record.context.version == vim.lsp.util.buf_versions[buf] and client and client.attached_buffers[buf] then result[#result + 1] = record end
  end
  return result
end
local function show(hints)
  local lines = { '```typescript' }
  for _, hint in ipairs(hints) do vim.list_extend(lines, vim.split(label(hint), '\n', { plain = true })) end
  lines[#lines + 1] = '```'
  vim.lsp.util.open_floating_preview(lines, 'markdown', { border = 'rounded', focusable = true,
    focus_id = 'movim_type_hint', max_width = 90, max_height = 24 })
end
function M.show_line(buf, line)
  local hints = {}
  for _, record in ipairs(current(buf)) do
    for _, hint in ipairs(record.hints) do
      if hint.kind == 1 and hint.position.line == line - 1 then hints[#hints + 1] = hint end
    end
  end
  if #hints > 0 then show(hints) end
end
function M.mouse()
  local pos = vim.fn.getmousepos()
  if pos.line == 0 or pos.winid == 0 or not vim.api.nvim_win_is_valid(pos.winid) then return '<LeftMouse>' end
  local buf = vim.api.nvim_win_get_buf(pos.winid)
  local line = vim.api.nvim_buf_get_lines(buf, pos.line - 1, pos.line, false)[1] or ''
  for _, record in ipairs(current(buf)) do
    for _, hint in ipairs(record.hints) do
      if hint.kind == 1 and hint.position.line == pos.line - 1 then
        local byte = vim.str_byteindex(line, record.encoding, hint.position.character, false)
        -- Inline virtual text maps back to its insertion byte in getmousepos.
        local anchor = vim.fn.screenpos(pos.winid, pos.line, byte + 1)
        if pos.column == byte + 1 and anchor.row == pos.screenrow and pos.screencol >= anchor.col and pos.screencol < anchor.curscol then
          vim.schedule(function()
            if vim.api.nvim_win_is_valid(pos.winid) and vim.api.nvim_win_get_buf(pos.winid) == buf
                and vim.api.nvim_buf_is_valid(buf) and record.context.version == vim.lsp.util.buf_versions[buf] then
              vim.api.nvim_set_current_win(pos.winid)
              show({ hint })
            end
          end)
          return '<Ignore>'
        end
      end
    end
  end
  return '<LeftMouse>'
end
function M.setup()
  vim.api.nvim_create_autocmd('BufWipeout', {
    group = vim.api.nvim_create_augroup('movim-compact-hints', { clear = true }),
    callback = function(args) records[args.buf] = nil end,
  })
  vim.api.nvim_create_autocmd('LspDetach', {
    group = 'movim-compact-hints', callback = function(args)
      if records[args.buf] then records[args.buf][args.data.client_id] = nil end
    end,
  })
end
return M
