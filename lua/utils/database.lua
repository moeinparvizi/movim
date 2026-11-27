local M = {}
local helper = vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2)), 'sqlite-query.cjs')
local drivers = {
  SQLite = { {'node', '--disable-warning=ExperimentalWarning', helper}, {'local.db'}, 'SELECT type, name FROM sqlite_schema ORDER BY name;' },
  PostgreSQL = { {'psql', '-X', '-w', '-v', 'ON_ERROR_STOP=1'}, {'-d', 'postgres'}, '\\dt' },
  MySQL = { {'mysql', '--batch'}, {'-h', 'localhost', 'database'}, 'SHOW TABLES;' },
  MariaDB = { {'mariadb', '--batch'}, {'-h', 'localhost', 'database'}, 'SHOW TABLES;' },
  ['SQL Server'] = { {'sqlcmd', '-b'}, {'-S', 'localhost', '-E'}, 'SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES;\nGO' },
  MongoDB = { {'mongosh', '--quiet'}, {'mongodb://localhost:27017/test'}, 'show collections', 'javascript' },
  Redis = { {'redis-cli', '--raw'}, {'-h', 'localhost'}, 'SCAN 0 COUNT 100', 'text' },
  ODBC = { {'isql', '-b'}, {'MyDSN'}, 'help' },
  Custom = { {}, {'your-client'}, nil, 'text' },
}
local function warn(msg) vim.notify(msg, vim.log.levels.WARN, { title = 'Database' }) end
local function read(path)
  if not vim.uv.fs_stat(path) then return {} end
  local ok, config = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(path), '\n')) end)
  if not ok or type(config) ~= 'table' or type(config.connections) ~= 'table' or not vim.islist(config.connections) then
    return nil, 'Expected a connections array in ' .. path
  end
  for index, entry in ipairs(config.connections) do
    if type(entry) ~= 'table' or type(entry.name) ~= 'string' or not drivers[entry.driver]
      or type(entry.args) ~= 'table' or not vim.islist(entry.args) then return nil, 'Invalid connection #' .. index end
    for _, arg in ipairs(entry.args) do if type(arg) ~= 'string' then return nil, 'Invalid client argument' end end
    if entry.schema ~= nil and type(entry.schema) ~= 'string' then return nil, 'Invalid schema command' end
  end
  return config.connections
end
local function scratch(ft)
  vim.cmd('botright new')
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype, vim.bo[buf].bufhidden, vim.bo[buf].swapfile = 'nofile', 'wipe', false
  vim.bo[buf].filetype = ft
  return buf
end
local function map(buf, key, action, desc)
  vim.keymap.set('n', key, action, {buffer = buf, desc = desc, silent = true})
end
local function execute(root, entry, query, view)
  if vim.trim(query) == '' then return warn('Enter a query first') end
  local argv = vim.list_extend(vim.deepcopy(drivers[entry.driver][1]), entry.args)
  if not argv[1] or vim.fn.executable(argv[1]) == 0 then return warn('Database client not found: ' .. tostring(argv[1])) end
  if view.result and vim.api.nvim_buf_is_valid(view.result) then vim.api.nvim_buf_delete(view.result, {force=true}) end
  local result = scratch('movim-db-result')
  view.result = result
  local function display(value)
    if not vim.api.nvim_buf_is_valid(result) then return end
    vim.bo[result].modifiable = true
    vim.api.nvim_buf_set_lines(result, 0, -1, false, vim.split(value, '\n', {plain=true}))
    vim.bo[result].modifiable = false
  end
  display('Running · ' .. entry.name .. '   |   q close / cancel')
  local received, chunks, clipped = 0, {}, false
  local function collect(err, data)
    data = data or err
    if not data then return end
    local left = 1024 * 1024 - received
    if left > 0 then chunks[#chunks + 1] = data:sub(1, left) end
    received = received + #data
    if received > 1024 * 1024 then clipped = true end
  end
  local ok, job = pcall(vim.system, argv, { cwd=root, stdin=query .. '\n', stdout=collect, stderr=collect }, vim.schedule_wrap(function(done)
    local body = table.concat(chunks):gsub('\r\n', '\n'):gsub('%z', ' ')
    display(entry.name .. ' · ' .. (done.code == 0 and 'OK' or 'Exit ' .. done.code) .. '\n' .. body .. (clipped and '\nOutput truncated' or ''))
  end))
  if not ok then display('Unable to start client: ' .. tostring(job)) end
  if ok then vim.api.nvim_create_autocmd('BufWipeout', {buffer=result, once=true, callback=function()
    if not job:is_closing() then job:kill(15) end
  end}) end
  map(result, 'q', function() vim.cmd.close() end, 'Close result')
end
function M.open()
  local root = vim.fs.normalize(vim.fn.getcwd())
  local path = vim.fs.joinpath(root, '.movim', 'databases.json')
  local panel = scratch('movim-database')
  local view = {}
  local entries
  local function refresh()
    if not vim.api.nvim_buf_is_valid(panel) then return end
    local err
    entries, err = read(path)
    local lines = {'DATABASE  /  ' .. vim.fs.basename(root), 'Enter query   s schema   a add   e settings   r refresh   q close', ''}
    for _, entry in ipairs(entries or {}) do lines[#lines+1] = '  ' .. entry.name .. '   ·   ' .. entry.driver end
    if err or #lines == 3 then lines[#lines+1] = err or 'No connections yet. Press a to add one.' end
    vim.bo[panel].modifiable = true
    vim.api.nvim_buf_set_lines(panel, 0, -1, false, lines)
    vim.bo[panel].modifiable = false
  end
  local function selected() return (entries or {})[vim.api.nvim_win_get_cursor(0)[1]-3] end
  map(panel, '<CR>', function()
    local entry = selected()
    if not entry then return end
    local buf = scratch(drivers[entry.driver][4] or 'sql')
    vim.bo[buf].bufhidden = 'hide'
    vim.wo.winbar = ' Query: ' .. entry.name:gsub('%%', '%%%%') .. '   |   Ctrl-Enter or F5: run'
    local function run() execute(root, entry, table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'), view) end
    map(buf, '<C-CR>', run, 'Execute query')
    map(buf, '<F5>', run, 'Execute query')
  end, 'Open query console')
  map(panel, 's', function()
    local entry = selected()
    if not entry then return end
    local query = entry.schema or drivers[entry.driver][3]
    if query then execute(root, entry, query, view) else warn('Set schema in the connection settings first') end
  end, 'Browse schema')
  map(panel, 'a', function()
    local choices = vim.tbl_keys(drivers)
    table.sort(choices)
    vim.ui.select(choices, {prompt='Database driver'}, function(driver)
      if not driver then return end
      vim.ui.input({prompt='Connection name: ', default=driver}, function(name)
        if not name or vim.trim(name) == '' then return end
        vim.ui.input({prompt='Client arguments (JSON array): ', default=vim.json.encode(drivers[driver][2])}, function(answer)
          if not answer then return end
          local ok, args = pcall(vim.json.decode, answer)
          if not ok or type(args) ~= 'table' or not vim.islist(args) then return warn('Expected a JSON array of strings') end
          for _, arg in ipairs(args) do if type(arg) ~= 'string' then return warn('Arguments must be strings') end end
          local current, err = read(path)
          if not current then return warn(err) end
          current[#current+1] = {name=name, driver=driver, args=args}
          vim.fn.mkdir(vim.fs.dirname(path), 'p')
          if vim.fn.writefile({vim.json.encode({connections=current})}, path) ~= 0 then return warn('Could not save connection') end
          refresh()
        end)
      end)
    end)
  end, 'Add connection')
  map(panel, 'e', function()
    vim.fn.mkdir(vim.fs.dirname(path), 'p')
    vim.cmd.split(vim.fn.fnameescape(path))
    if not vim.uv.fs_stat(path) then vim.api.nvim_buf_set_lines(0, 0, -1, false, {'{"connections":[]}'}) end
  end, 'Edit connections')
  map(panel, 'r', refresh, 'Refresh connections')
  map(panel, 'q', function() vim.cmd.close() end, 'Close database')
  vim.api.nvim_create_autocmd('BufEnter', {buffer=panel, callback=refresh})
  refresh()
  vim.api.nvim_win_set_cursor(0, {4,0})
end
return M
