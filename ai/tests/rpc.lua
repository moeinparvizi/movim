vim.opt.runtimepath:prepend(vim.fn.getcwd() .. '/ai')
local pi = require('movim_ai.pi')
if vim.env.MOVIM_AI_TEST_TRACE == '1' then
  local decoder = pi.decoder
  pi.decoder = function(on_message, on_error)
    return decoder(function(event)
      print('RPC ' .. tostring(event.type) .. ' ' .. tostring(event.command) .. ' ' .. tostring(event.id))
      on_message(event)
    end, on_error)
  end
end
local sessions = require('movim_ai.sessions')
local editor = require('movim_ai.editor')
local config = { root = vim.env.MOVIM_AI_TEST_RUNTIME or (vim.fn.getcwd() .. '/ai'), node = vim.env.MOVIM_AI_TEST_NODE or 'node',
  provider = 'movim-test', model = 'test-model', base_url = vim.env.MOVIM_AI_TEST_URL,
  api = 'openai-completions', api_key_env = 'MOVIM_AI_TEST_KEY', context_window = 32768, output_tokens = 4096,
  sensitive_policy = 'deny', sensitive_patterns = {}, timeout_ms = 120000 }
local function create(content)
  local b = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(b, 0, -1, true, { content })
  local tab = sessions.new(content)
  return tab, sessions.send(tab, 'Replace only this selection', editor.capture(b, { 0, 0, 0, #content }), config), b
end
local a, ar, ab = create('alpha فارسی')
local b, br, bb = create('beta 🙂')
assert(vim.wait(130000, function() return a.status ~= 'processing' and b.status ~= 'processing' end, 10), 'RPC timeout')
assert(a.status == 'review', ar.error or a.status)
assert(b.status == 'review', br.error or b.status)
assert(ar.proposal.replacementText == 'replacement alpha فارسی', ar.output)
assert(br.proposal.replacementText == 'replacement beta 🙂', br.output)
assert(vim.api.nvim_buf_get_lines(ab, 0, -1, true)[1] == 'alpha فارسی')
assert(vim.api.nvim_buf_get_lines(bb, 0, -1, true)[1] == 'beta 🙂')
local c, cr, cb = create('CANCEL_ME')
assert(vim.wait(130000, function() return cr.output ~= '' or cr.status ~= 'processing' end, 10), 'Cancellation request did not stream')
assert(cr.output ~= '' and cr.status == 'processing', cr.error or 'Expected partial stream')
sessions.cancel(c)
vim.wait(3500, function() return false end, 20)
assert(cr.status == 'cancelled' and cr.proposal == nil)
assert(vim.api.nvim_buf_get_lines(cb, 0, -1, true)[1] == 'CANCEL_ME')
sessions.shutdown()
print('PASS real pinned Pi RPC: two processes, streaming, Unicode, validated proposals, no writes, cancellation')
vim.cmd('qa!')
