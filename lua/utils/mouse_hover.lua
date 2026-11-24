local M = {}
local generation = 0
local popup
local pending = {}
local last_position

local function clear()
  generation = generation + 1
  for _, request in ipairs(pending) do
    pcall(request.client.cancel_request, request.client, request.id)
  end
  pending = {}
  if popup and vim.api.nvim_win_is_valid(popup) then pcall(vim.api.nvim_win_close, popup, true) end
  popup, last_position = nil, nil
end

local function keyword_at(buf, line, column)
  return vim.api.nvim_buf_call(buf, function()
    local offset = 0
    while offset < #line do
      local match = vim.fn.matchstrpos(line, [[\k\+]], offset)
      if match[2] < 0 or match[2] > column then return false end
      if column < match[3] then return true end
      offset = match[3]
    end
    return false
  end)
end

function M.move()
  local pos = vim.fn.getmousepos()
  local key = table.concat({ pos.winid, pos.line, pos.column, pos.screenrow, pos.screencol }, ':')
  if key == last_position then return end
  clear()
  if pos.winid == 0 or pos.line == 0 or pos.column == 0 or not vim.api.nvim_win_is_valid(pos.winid) then return end
  local buf = vim.api.nvim_win_get_buf(pos.winid)
  if vim.bo[buf].buftype ~= '' then return end
  local line = vim.api.nvim_buf_get_lines(buf, pos.line - 1, pos.line, false)[1] or ''
  local column = pos.column - 1
  if column >= #line or not keyword_at(buf, line, column) then return end
  local clients = vim.lsp.get_clients({ bufnr = buf, method = 'textDocument/hover' })
  if #clients == 0 then return end
  last_position = key
  local token, tick = generation, vim.api.nvim_buf_get_changedtick(buf)
  vim.defer_fn(function()
    if token ~= generation or not vim.api.nvim_win_is_valid(pos.winid) or not vim.api.nvim_buf_is_valid(buf)
        or vim.api.nvim_win_get_buf(pos.winid) ~= buf or vim.api.nvim_buf_get_changedtick(buf) ~= tick then return end
    local shown = false
    for _, client in ipairs(clients) do
      local params = { textDocument = { uri = vim.uri_from_bufnr(buf) }, position = {
        line = pos.line - 1, character = vim.str_utfindex(line, client.offset_encoding or 'utf-16', column, false),
      } }
      local sent, id = client:request('textDocument/hover', params, function(err, result)
        if err or not result or not result.contents or token ~= generation or shown
            or not vim.api.nvim_buf_is_valid(buf) or vim.api.nvim_buf_get_changedtick(buf) ~= tick
            or not vim.api.nvim_win_is_valid(pos.winid) or vim.api.nvim_win_get_buf(pos.winid) ~= buf then return end
        local lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
        if #lines == 0 or vim.trim(table.concat(lines, '')) == '' then return end
        local existing = vim.b[buf].lsp_floating_preview
        if existing and vim.api.nvim_win_is_valid(existing) then return end
        shown = true
        vim.api.nvim_win_call(pos.winid, function()
          local _, win = vim.lsp.util.open_floating_preview(lines, 'markdown', {
            relative = 'mouse', border = 'rounded', focusable = false, max_width = 70, max_height = 12,
          })
          popup = win
          pcall(vim.api.nvim_win_set_config, win, { mouse = false })
        end)
      end, buf)
      if sent and id then pending[#pending + 1] = { client = client, id = id } end
    end
  end, 500)
end

function M.setup()
  vim.o.mousemoveevent = true
  vim.keymap.set({ 'n', 'i' }, '<MouseMove>', M.move, { silent = true })
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'InsertCharPre', 'BufLeave', 'WinScrolled', 'ModeChanged' }, {
    group = vim.api.nvim_create_augroup('movim-mouse-hover', { clear = true }), callback = clear,
  })
end

return M
