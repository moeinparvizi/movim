vim.opt.rtp:prepend(vim.fn.getcwd())
local workspace = vim.env.MOVIM_GIT_TEST_WORKSPACE:gsub('\\', '/')
package.loaded['utils.workspace'] = { root = workspace }
local messages, prompts = {}, 0
vim.notify = function(message) messages[#messages + 1] = message end
vim.ui.select = function(items, opts, callback)
  assert(opts.prompt:find('Pull conflict', 1, true), opts.prompt)
  prompts = prompts + 1
  callback('Continue with remaining repositories')
end
require('utils.git').pull_workspace()
assert(vim.wait(50000, function()
  for _, message in ipairs(messages) do if message:find('Workspace pull:', 1, true) then return true end end
end, 50), 'Pull did not complete')
assert(prompts == 1, 'Expected exactly one conflict popup')
local summary = messages[#messages]
assert(summary:find('1 updated, 1 need attention, 0 not attempted', 1, true), summary)
print('PASS conflict popup and complete summary')
