vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.g.mapleader = ' '
local root = assert(vim.env.MOVIM_UPDATE_TEST_ROOT)
local updater = require('utils.updates')
local notices = {}
vim.notify = function(message) notices[#notices + 1] = message end
local pending = root .. '/.movim-update/pending.json'
assert(vim.fn.filereadable(pending) == 1)
assert(not updater.bootstrap(root))
assert(vim.fn.filereadable(pending) == 1, 'headless runs must not apply user updates')
local uis = vim.api.nvim_list_uis
vim.api.nvim_list_uis = function() return { {} } end
assert(updater.bootstrap(root), 'changed configuration must request a fresh entrypoint')
vim.api.nvim_list_uis = uis
assert(vim.fn.filereadable(pending) == 0, 'interactive bootstrap must apply before config loads')
local manifest = vim.json.decode(table.concat(vim.fn.readfile(root .. '/release.json'), '\n'))
assert(manifest.version == '1.1.11')
assert(vim.fn.readfile(root .. '/user.lua')[1] == '-- my preferences')
updater.setup()
assert(vim.fn.exists(':MovimUpdate') == 2)
assert(vim.fn.maparg(' uU', 'n') ~= '')

local marker, lockfile = root .. '/.movim-update/sync.json', root .. '/lazy-lock.json'
local locked = vim.fn.readfile(lockfile, 'b')
vim.fn.writefile({ '{}' }, marker)
local failed, calls = true, 0
package.loaded['lazy.core.config'] = { plugins = { test = { name = 'test', _ = { tasks = { { has_errors = function() return failed end } } } } } }
package.loaded['lazy'] = {
  install = function(opts) assert(opts.wait and opts.lockfile); calls = calls + 1; vim.fn.writefile({ 'changed by lazy' }, lockfile) end,
  restore = function(opts) assert(opts.wait); calls = calls + 1 end,
}
updater.sync_plugins()
assert(vim.fn.filereadable(marker) == 1, 'failed plugin sync must remain retryable')
assert(vim.deep_equal(locked, vim.fn.readfile(lockfile, 'b')), 'release lockfile must survive failed plugin sync')
failed = false
updater.sync_plugins()
assert(calls == 3)
assert(vim.fn.filereadable(marker) == 0)
assert(vim.deep_equal(locked, vim.fn.readfile(lockfile, 'b')))

local system, callback = vim.system, nil
local saved, started = 0, 0
package.loaded['utils.workspace'] = { ready = true, save = function(force) assert(force); saved = saved + 1; return true end }
vim.system = function(args, opts, cb)
  assert(args[3] == 'install' and args[4] == root and opts.text)
  started = started + 1; callback = cb
end
updater.install(); updater.install()
assert(saved == 0 and started == 1, 'project writes are not required and downloads cannot overlap')
callback({ code = 0, stdout = '{"status":"installed","version":"1.1.12","backup":"backups/1234"}' })
assert(vim.wait(1000, function() return notices[#notices]:find('Installed movim 1.1.12', 1, true) end))
vim.system = system
print('PASS Lua interactive bootstrap, headless isolation, update command/shortcut, workspace checkpoint, plugin retry and pinned lockfile')
