local M = {}
local api = 'https://api.github.com/repos/moeinparvizi/movim/releases/latest'
local page = 'https://github.com/moeinparvizi/movim/releases/latest'
local cache = vim.fn.stdpath('state') .. '/movim-update-check.json'
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
local busy = false

local function command(mode)
  local node = vim.fn.exepath('node')
  if node == '' then error('Node.js is required for movim updates.') end
  return { node, root .. '/lua/utils/update-engine.cjs', mode, root }
end

-- Called before loading configuration or plugins. Applying an already downloaded
-- package needs no network and never touches stdpath(data/state) or project files.
function M.bootstrap(config_root)
  root = config_root or root
  if #vim.api.nvim_list_uis() == 0 then return end
  local dir = root .. '/.movim-update/'
  if vim.fn.filereadable(dir .. 'pending.json') == 0 and vim.fn.filereadable(dir .. 'transaction.json') == 0 then return end
  local ok, result = pcall(function() return vim.system(command('apply'), { text = true }):wait(30000) end)
  if not ok or result.code ~= 0 then
    vim.schedule(function() vim.notify('movim update was not applied. Your files were preserved.\n' .. tostring(ok and result.stderr or result), vim.log.levels.ERROR) end)
    return
  end
  local parsed, info = pcall(vim.json.decode, result.stdout)
  if parsed and info.status == 'installed' then
    vim.schedule(function() vim.notify('movim updated to ' .. info.version .. '. Backup: ' .. info.backup) end)
  elseif parsed and info.status == 'recovered' then
    vim.schedule(function() vim.notify('Interrupted movim update rolled back. Run :MovimUpdate to try again.', vim.log.levels.WARN) end)
  end
end

function M.install()
  if busy then vim.notify('A movim update is already downloading.'); return end
  if vim.fn.filereadable(root .. '/.movim-update/sync.json') == 1 then M.sync_plugins(); return end
  local workspace = package.loaded['utils.workspace']
  if workspace and workspace.ready and not workspace.save(true) then return end
  local ok, args = pcall(command, 'prepare')
  if not ok then vim.notify(tostring(args), vim.log.levels.ERROR); return end
  busy = true
  vim.notify('Downloading and checking the latest movim release...', vim.log.levels.INFO, { title = 'movim update' })
  vim.system(args, { text = true }, function(result)
    vim.schedule(function()
      busy = false
      if result.code ~= 0 then vim.notify('movim update stopped.\n' .. (result.stderr or ''), vim.log.levels.ERROR); return end
      local parsed, info = pcall(vim.json.decode, result.stdout or '')
      if not parsed then vim.notify('Invalid response from movim updater.', vim.log.levels.ERROR); return end
      if info.status == 'current' then vim.notify('movim is up to date (' .. info.version .. ').'); return end
      vim.notify('movim ' .. info.version .. ' is ready. Close all movim windows and reopen to apply it. Your workspace will be restored.', vim.log.levels.INFO, { title = 'movim update' })
    end)
  end)
end

function M.sync_plugins()
  if busy then return end
  local marker = root .. '/.movim-update/sync.json'
  if vim.fn.filereadable(marker) == 0 then return end
  busy = true
  local ok, err = pcall(function()
    local lazy = require('lazy')
    local function verify()
      for _, plugin in pairs(require('lazy.core.config').plugins) do
        for _, task in ipairs(plugin._.tasks or {}) do
          if task:has_errors() then error('Plugin synchronization failed: ' .. plugin.name) end
        end
      end
    end
    local lockfile = root .. '/lazy-lock.json'
    local contents = vim.fn.readfile(lockfile, 'b')
    local synced, failure = pcall(function()
      lazy.install({ wait = true, show = false, lockfile = true }); verify()
      lazy.restore({ wait = true, show = false }); verify()
    end)
    vim.fn.writefile(contents, lockfile, 'b')
    if not synced then error(failure) end
  end)
  busy = false
  if ok then
    vim.fn.delete(marker)
    vim.notify('movim plugins match the new release. Restart once more if a loaded plugin changed.')
  else
    vim.notify('movim files updated; plugin sync needs internet/Git. Run :MovimUpdate to retry.\n' .. tostring(err), vim.log.levels.WARN)
  end
end

local function version(value)
  local a, b, c = tostring(value):match('^[vV]?(%d+)%.(%d+)%.(%d+)$')
  if not a then return nil end
  return { tonumber(a), tonumber(b), tonumber(c) }
end

function M.is_newer(current, latest)
  local a, b = version(current), version(latest)
  if not a or not b then return false end
  for i = 1, 3 do
    if a[i] ~= b[i] then return b[i] > a[i] end
  end
  return false
end

function M.check(manual)
  if vim.fn.executable('curl') ~= 1 then
    if manual then vim.notify('Update check requires curl.', vim.log.levels.WARN) end
    return
  end
  if not manual then
    local ok, content = pcall(vim.fn.readfile, cache)
    if ok then
      local parsed, data = pcall(vim.json.decode, table.concat(content, '\n'))
      if parsed and type(data) == 'table' and tonumber(data.checked) and os.time() - data.checked < 86400 then return end
    end
  end
  vim.system({ 'curl', '--fail', '--silent', '--show-error', '--location', '--max-time', '8',
    '-H', 'Accept: application/vnd.github+json', '-H', 'User-Agent: movim-update-check', api }, { text = true }, function(result)
    vim.schedule(function()
      pcall(vim.fn.mkdir, vim.fn.stdpath('state'), 'p')
      pcall(vim.fn.writefile, { vim.json.encode({ checked = os.time() }) }, cache)
      if result.code ~= 0 then
        if manual then vim.notify('Could not check releases. Check your connection or visit ' .. page, vim.log.levels.WARN) end
        return
      end
      local ok, release = pcall(vim.json.decode, result.stdout or '')
      if not ok or type(release) ~= 'table' or not version(release.tag_name) or release.prerelease or release.draft then
        if manual then vim.notify('No stable movim release is available yet.', vim.log.levels.INFO) end
        return
      end
      local current = require('config.version')
      if M.is_newer(current, release.tag_name) then
        vim.notify(('movim %s is available (installed: %s). Press Space u U or run :MovimUpdate to install.'):format(release.tag_name, current), vim.log.levels.INFO, { title = 'movim update' })
      elseif manual then
        vim.notify(('movim is up to date (%s).'):format(current), vim.log.levels.INFO)
      end
    end)
  end)
end

function M.setup()
  vim.api.nvim_create_user_command('MovimUpdate', M.install, { desc = 'Download and stage the latest movim release' })
  vim.api.nvim_create_user_command('MovimCheckUpdate', function() M.check(true) end, { desc = 'Check for a movim release' })
  vim.keymap.set('n', '<leader>uU', M.install, { desc = 'Update movim' })
  if #vim.api.nvim_list_uis() > 0 then vim.defer_fn(M.sync_plugins, 1000) end
  if vim.g.movim_check_updates ~= false then vim.defer_fn(function() M.check(false) end, 5000) end
end

return M
