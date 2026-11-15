local M = { tabs = {}, selected = nil, next_id = 0 }
local function changed() if M.on_change then M.on_change() end end
function M.new(name)
  M.next_id = M.next_id + 1
  local tab = { id = M.next_id, name = name or ('Chat ' .. M.next_id), attachments = {}, contexts = {}, history = {}, requests = {}, status = 'idle' }
  M.tabs[#M.tabs + 1] = tab; M.selected = tab.id; changed(); return tab
end
function M.current()
  for _, tab in ipairs(M.tabs) do if tab.id == M.selected then return tab end end
  return M.new()
end
function M.cancel(tab)
  if tab.request and tab.status == 'processing' then
    tab.request.status, tab.status = 'cancelled', 'cancelled'
    tab.history[#tab.history + 1] = { role = 'system', text = 'Request cancelled. Pi session stopped; next request starts fresh.' }
    if tab.client then tab.client:cancel(); tab.client = nil end
    changed()
  end
end
function M.close(tab)
  M.cancel(tab)
  if tab.client then tab.client:close() end
  for i, value in ipairs(M.tabs) do if value == tab then table.remove(M.tabs, i); break end end
  if M.selected == tab.id then M.selected = M.tabs[1] and M.tabs[1].id or nil end
  changed()
end
function M.attach(tab, snapshot)
  for i, old in ipairs(tab.attachments) do if old.buf == snapshot.buf then tab.attachments[i] = snapshot; changed(); return end end
  tab.attachments[#tab.attachments + 1] = snapshot; changed()
end
function M.send(tab, prompt, snapshot, config)
  assert(tab.status ~= 'processing', 'This tab is processing; cancel or wait first')
  assert(type(prompt) == 'string' and prompt:match('%S'), 'Prompt is empty')
  -- Context used by earlier turns can become stale even when it is not attached
  -- to this turn. Retain and validate it until the user refreshes explicitly.
  local contexts = vim.deepcopy(tab.contexts)
  for _, s in ipairs(tab.attachments) do contexts[s.buf] = s end
  if snapshot then contexts[snapshot.buf] = snapshot end
  local attachments = {}
  for _, s in pairs(contexts) do
    local current, reason = require('movim_ai.editor').current(s)
    assert(current, 'Stale conversation context: ' .. (reason or '') .. '. Use :AIRefresh, or reselect the code.')
    if not snapshot or s.buf ~= snapshot.buf then attachments[#attachments + 1] = s end
  end
  local request = { id = ('request-%d-%s'):format(tab.id, vim.uv.hrtime()), prompt = prompt, snapshot = snapshot, status = 'processing', output = '' }
  request.outcome = tab.outcome
  local message, err = require('movim_ai.context').build(request, attachments, config)
  assert(message, err)
  local fits, bound = require('movim_ai.context').fits(message, '', config.context_window, config.output_tokens)
  assert(fits, ('Context exceeds safe budget (%d bytes/tokens). Remove attachments, choose a larger model, or narrow the source file explicitly. Nothing was sent.'):format(bound))
  if tab.request and tab.request.status == 'review' then tab.request.status = 'superseded' end
  tab.contexts = contexts
  tab.request = request; tab.requests[#tab.requests + 1] = request; tab.status = 'processing'
  tab.history[#tab.history + 1] = { role = 'user', text = prompt }
  local ok, failure = pcall(function()
    if not tab.client or tab.client.closed then
      tab.client = (config.adapter or require('movim_ai.pi').new)(config, tab.id)
    end
    tab.client:send(message, function(kind, value)
      if tab.request ~= request or request.status ~= 'processing' then return end
      if kind == 'delta' then request.output = request.output .. value
      elseif kind == 'error' then
        request.status, tab.status = 'error', 'error'; request.error = value
      elseif kind == 'done' then
        request.output = value
        tab.history[#tab.history + 1] = { role = 'assistant', text = value }
        if snapshot then
          local valid, proposal, reason = pcall(require('movim_ai.validator').parse, value, request)
          if valid and proposal then request.proposal = proposal; request.status, tab.status = 'review', 'review'
          else request.error = valid and reason or tostring(proposal); request.status, tab.status = 'error', 'error' end
        else request.status, tab.status = 'complete', 'complete' end
      end
      changed()
    end)
  end)
  if not ok then request.status, tab.status = 'error', 'error'; request.error = tostring(failure) end
  changed(); return request
end
function M.resolve(tab, action)
  local request = tab.request
  assert(request and request.status == 'review', 'No proposal ready for review')
  if action == 'apply' then require('movim_ai.apply').apply(request, request.proposal)
  else request.status = 'rejected' end
  tab.status = request.status
  local outcome = 'Proposal ' .. request.id .. ' ' .. request.status .. '. The file was not saved.'
  tab.history[#tab.history + 1] = { role = 'system', text = outcome }
  -- Force explicit outcomes into the next prompt without sending anything now.
  tab.outcome = outcome
  changed()
end
function M.shutdown()
  for _, tab in ipairs(M.tabs) do M.cancel(tab); if tab.client then tab.client:close() end end
end
return M
