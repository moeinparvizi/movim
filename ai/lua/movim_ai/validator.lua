local M = {}
function M.parse(text, request)
  if type(text) ~= 'string' or #text > 1024 * 1024 then return nil, 'Missing or oversized proposal' end
  local ok, value = pcall(vim.json.decode, text)
  if not ok or type(value) ~= 'table' then return nil, 'Expected a complete JSON object (no Markdown fences)' end
  local allowed = { requestId = true, snapshotId = true, replacementText = true, explanation = true }
  for key in pairs(value) do if not allowed[key] then return nil, 'Unexpected proposal field: ' .. tostring(key) end end
  for key in pairs(allowed) do if type(value[key]) ~= 'string' then return nil, 'Missing string field: ' .. key end end
  if value.requestId ~= request.id or value.snapshotId ~= request.snapshot.id then return nil, 'Proposal does not match this request/snapshot' end
  if value.replacementText:find('\0', 1, true) then return nil, 'NUL bytes are not supported' end
  if vim.str_utfindex(value.replacementText, 'utf-8', #value.replacementText, false) == nil then return nil, 'Invalid text' end
  return value
end
return M
