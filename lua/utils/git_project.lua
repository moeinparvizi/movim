-- Discover workspace repositories in bounded batches without changing editor cwd.
local M = {}
local skip = { ['.git'] = true, node_modules = true, vendor = true, ['.isolated'] = true,
  ['.tools'] = true, ['.cache'] = true, ['.venv'] = true, target = true, build = true, dist = true }
-- Pull scans the entire workspace, including nested repositories and worktrees.
-- Never follow directory symlinks: they may escape the workspace or form loops.
function M.discover_all(root, callback)
  local queue, index, found, errors = { root }, 1, {}, {}
  local parent = vim.fs.root(root, '.git')
  if parent and vim.fs.normalize(parent) ~= vim.fs.normalize(root) then found[#found + 1] = parent end
  local function batch()
    local last = index + 39
    while index <= #queue and index <= last do
      local path = queue[index]; index = index + 1
      local handle, err = vim.uv.fs_scandir(path)
      if handle then
        while true do
          local name, kind = vim.uv.fs_scandir_next(handle)
          if not name then break end
          if name == '.git' and (kind == 'directory' or kind == 'file') then
            found[#found + 1] = path
          elseif kind == 'directory' and name ~= '.git' then
            queue[#queue + 1] = vim.fs.joinpath(path, name)
          end
        end
      else errors[#errors + 1] = path .. ': ' .. tostring(err) end
    end
    if index <= #queue then vim.schedule(batch) else table.sort(found); callback(found, errors) end
  end
  vim.schedule(batch)
end
function M.choose(callback)
  local root = require('utils.workspace').root or vim.fn.getcwd()
  local queue, index, found, seen = { { root, 0 } }, 1, {}, {}
  local function add(path)
    path = vim.fs.normalize(path):gsub('/$', '')
    local key = vim.fn.has('win32') == 1 and path:lower() or path
    if not seen[key] then seen[key] = true; found[#found + 1] = path end
  end
  local parent = vim.fs.root(root, '.git')
  if parent then add(parent) end
  local file = vim.api.nvim_buf_get_name(0)
  if file ~= '' and vim.bo.buftype == '' then
    local repo = vim.fs.root(file, '.git'); if repo then add(repo) end
  end
  local function finish()
    table.sort(found)
    local function select(path)
      if not path then return end
      local ok, err = pcall(vim.system, { 'git', '-C', path, 'rev-parse', '--show-toplevel' },
        { text = true, timeout = 10000 }, function(result)
          vim.schedule(function()
            if result.code ~= 0 then
              return vim.notify('Repository is unavailable: ' .. path .. '\n' .. vim.trim(result.stderr or ''), vim.log.levels.WARN)
            end
            if (require('utils.workspace').root or vim.fn.getcwd()) ~= root then return end
            callback(vim.trim(result.stdout))
          end)
        end)
      if not ok then vim.notify('Cannot start Git: ' .. tostring(err), vim.log.levels.ERROR) end
    end
    if #found == 0 then return vim.notify('No Git repositories found in this workspace (search depth: 3)', vim.log.levels.WARN) end
    if #found == 1 then return select(found[1]) end
    vim.ui.select(found, { prompt = 'Git project', format_item = function(path)
      return vim.fn.fnamemodify(path, ':t') .. '  —  ' .. vim.fn.fnamemodify(path, ':~')
    end }, select)
  end
  local function batch()
    local stop = math.min(index + 39, 3000)
    while index <= #queue and index <= stop do
      local item = queue[index]; index = index + 1
      if vim.uv.fs_stat(item[1] .. '/.git') then add(item[1]) end
      if item[2] < 3 then
        local handle = vim.uv.fs_scandir(item[1])
        if handle then
          while #queue < 3000 do
            local name, kind = vim.uv.fs_scandir_next(handle)
            if not name then break end
            if kind == 'directory' and not skip[name] then queue[#queue + 1] = { item[1] .. '/' .. name, item[2] + 1 } end
          end
        end
      end
    end
    if index <= #queue and index <= 3000 then vim.schedule(batch) else finish() end
  end
  vim.schedule(batch)
end
function M.diff()
  M.choose(function(path) vim.cmd.DiffviewOpen({ args = { '-C' .. path } }) end)
end
function M.telescope(kind)
  M.choose(function(path) require('telescope.builtin')[kind]({ cwd = path }) end)
end
function M.tree()
  M.choose(function(path) require('neo-tree.command').execute({ source = 'git_status', position = 'float', dir = path }) end)
end
return M
