local M = {}
function M.apply(request, proposal)
  assert(request.status == 'review', 'Only a proposal ready for review can be applied once')
  local parsed, err = require('movim_ai.validator').parse(vim.json.encode(proposal), request)
  assert(parsed, err)
  local s = request.snapshot
  local current, reason = require('movim_ai.editor').current(s)
  assert(current, reason)
  assert(vim.bo[s.buf].modifiable and not vim.bo[s.buf].readonly, 'Source buffer is read-only')
  local levels = vim.bo[s.buf].undolevels
  if levels == -123456 then levels = vim.go.undolevels end
  assert(levels >= 0, 'Undo is disabled in the source buffer; enable undo before Apply')
  local r = s.range
  local lines = vim.split(parsed.replacementText, '\n', { plain = true })
  -- Explicitly close the preceding undo block, including scripted/API callers.
  -- See :help undo-break; setting the same local value preserves undo history.
  vim.api.nvim_buf_call(s.buf, function() vim.cmd('let &l:undolevels = &l:undolevels') end)
  if s.kind == 'line' then
    if parsed.replacementText == '' then lines = {} end
    vim.api.nvim_buf_set_lines(s.buf, r[1], r[3], true, lines)
  else
    vim.api.nvim_buf_set_text(s.buf, r[1], r[2], r[3], r[4], lines)
  end
  request.status = 'applied'
  return true
end
function M.diff(request, proposal)
  return vim.diff(request.snapshot.original .. '\n', proposal.replacementText .. '\n', { result_type = 'unified', ctxlen = 3 })
end
return M
