local M = {}
local api = 'https://api.github.com/repos/moeinparvizi/movim/releases/latest'
local page = 'https://github.com/moeinparvizi/movim/releases/latest'
local cache = vim.fn.stdpath('state') .. '/movim-update-check.json'

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
        vim.notify(('movim %s is available (installed: %s). Download: %s'):format(release.tag_name, current, page), vim.log.levels.INFO, { title = 'movim update' })
      elseif manual then
        vim.notify(('movim is up to date (%s).'):format(current), vim.log.levels.INFO)
      end
    end)
  end)
end

function M.setup()
  vim.api.nvim_create_user_command('MovimCheckUpdate', function() M.check(true) end, { desc = 'Check for a movim release' })
  if vim.g.movim_check_updates ~= false then vim.defer_fn(function() M.check(false) end, 5000) end
end

return M
