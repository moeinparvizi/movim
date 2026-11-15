local M = {}
local api = vim.api
local serial = 0
function M.snapshot(buf)
  assert(api.nvim_buf_is_valid(buf) and api.nvim_buf_is_loaded(buf), 'Source buffer is no longer loaded')
  assert(vim.bo[buf].buftype == '', 'Only file buffers can be attached')
  local lines = api.nvim_buf_get_lines(buf, 0, -1, true)
  local text = table.concat(lines, '\n')
  serial = serial + 1
  return { id = ('snapshot-%s-%d'):format(vim.uv.hrtime(), serial), buf = buf,
    path = api.nvim_buf_get_name(buf), language = vim.bo[buf].filetype,
    tick = api.nvim_buf_get_changedtick(buf), lines = lines, text = text, hash = vim.fn.sha256(text) }
end
function M.capture(buf, range, kind)
  local s = M.snapshot(buf)
  s.range, s.kind = vim.deepcopy(range), kind or 'character'
  if s.kind == 'line' then
    s.original = table.concat(api.nvim_buf_get_lines(buf, range[1], range[3], true), '\n')
  else
    s.original = table.concat(api.nvim_buf_get_text(buf, range[1], range[2], range[3], range[4], {}), '\n')
  end
  return s
end
function M.selection(mode, start_pos, end_pos)
  assert(mode ~= '\22', 'Block selection is not supported; use character or line Visual mode')
  assert(mode == 'v' or mode == 'V', 'Select code in Visual mode first')
  local buf = api.nvim_get_current_buf()
  local regions = vim.fn.getregionpos(start_pos, end_pos, {
    type = mode, exclusive = vim.o.selection == 'exclusive', eol = true,
  })
  assert(#regions > 0, 'Empty selection')
  local first, last = regions[1][1], regions[#regions][2]
  local row, col = first[2] - 1, math.max(0, first[3] - 1)
  local endrow = last[2] - 1
  if mode == 'V' then return M.capture(buf, { row, 0, endrow + 1, 0 }, 'line') end
  local line = api.nvim_buf_get_lines(buf, endrow, endrow + 1, true)[1]
  local endcol = math.max(0, last[3] - 1)
  if endcol < #line then endcol = endcol + #vim.fn.strcharpart(line:sub(endcol + 1), 0, 1) end
  return M.capture(buf, { row, col, endrow, math.min(#line, endcol) }, 'character')
end
function M.visual() return M.selection(vim.fn.mode(), vim.fn.getpos('v'), vim.fn.getpos('.')) end
function M.marked() return M.selection(vim.fn.visualmode(), vim.fn.getpos("'<"), vim.fn.getpos("'>")) end
function M.current(s)
  if not api.nvim_buf_is_valid(s.buf) or not api.nvim_buf_is_loaded(s.buf) then return false, 'Source buffer was closed' end
  if api.nvim_buf_get_name(s.buf) ~= s.path then return false, 'Source buffer identity/path changed' end
  if api.nvim_buf_get_changedtick(s.buf) ~= s.tick then return false, 'Source buffer changed; rerun with a fresh selection' end
  if table.concat(api.nvim_buf_get_lines(s.buf, 0, -1, true), '\n') ~= s.text then return false, 'Source snapshot changed' end
  return true
end
return M
