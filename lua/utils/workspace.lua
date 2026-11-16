-- Project workspaces: atomic, debounced state and recoverable unsaved drafts.
local M = { restoring = false, ready = false, stopped = false }
local api, uv = vim.api, vim.uv
local cache, states, signatures, index, pending = {}, {}, {}, nil, nil
local function normalize(path)
  local result = vim.fs.normalize(vim.fn.fnamemodify(path, ':p'))
  if result == '/' or result:match('^%a:/$') then return result end
  return result:gsub('/$', '')
end
local function id(path)
  return vim.fn.sha256(vim.fn.has('win32') == 1 and path:lower() or path)
end
local function folder() return M.directory or (vim.fn.stdpath('state') .. '/movim-workspaces') end
local function filename(root) return folder() .. '/' .. id(root) .. '.json' end
local function read(path)
  if vim.fn.filereadable(path) == 0 then return nil end
  local ok, value = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(path), '\n')) end)
  if ok and type(value) == 'table' then return value end
  return nil, 'Cannot read workspace state: ' .. path .. '. The original file was preserved.'
end
local function write(path, value)
  vim.fn.mkdir(folder(), 'p', 448)
  local temporary = path .. '.' .. vim.fn.getpid() .. '.tmp'
  local file, err = uv.fs_open(temporary, 'w', 384); assert(file, err)
  local ok, failure = pcall(function()
    local data = vim.json.encode(value)
    local offset = 0
    while offset < #data do
      local count, message = uv.fs_write(file, data:sub(offset + 1), offset)
      assert(count and count > 0, message or 'Workspace write failed'); offset = offset + count
    end
    assert(uv.fs_fsync(file))
  end)
  uv.fs_close(file)
  if ok then ok, failure = uv.fs_rename(temporary, path) end
  if not ok then uv.fs_unlink(temporary); error(failure) end
end
local function session_path(value, root)
  value = value:gsub('\\(.)', '%1'):gsub('^~', function() return vim.fn.expand('~') end)
  if not value:match('^[/\\]') and not value:match('^%a:[/\\]') then value = root .. '/' .. value end
  return normalize(value)
end
local function registry()
  if index then return index end
  index = read(folder() .. '/index.json') or { projects = {} }
  if type(index.projects) ~= 'table' then index.projects = {} end
  if type(index.last) ~= 'string' then index.last = nil end
  -- The project files are authoritative, even if the index was lost.
  for _, path in ipairs(vim.fn.glob(folder() .. '/*.json', false, true)) do
    if not path:match('/index%.json$') then
      local state = read(path)
      if state and type(state.root) == 'string' then index.projects[state.root] = { updated = tonumber(state.updated) or 0 } end
    end
  end
  if M.legacy_directory then
    local newest, stamp = nil, 0
    for _, path in ipairs(vim.fn.glob(M.legacy_directory .. '/*.vim', false, true)) do
      for _, line in ipairs(vim.fn.readfile(path, '', 30)) do
        local directory = line:match('^cd (.+)$')
        if directory then
          local project = session_path(directory, vim.fn.getcwd())
          local updated = (uv.fs_stat(path) or { mtime = { sec = 0 } }).mtime.sec
          if not index.projects[project] and vim.fn.isdirectory(project) == 1 then index.projects[project] = { updated = updated, legacy = path } end
          if updated > stamp and vim.fn.isdirectory(project) == 1 then newest, stamp = project, updated end
          break
        end
      end
    end
    if not index.last then index.last = newest end
  end
  return index
end
local function import_legacy(path, root)
  local result = { version = 1, root = root, buffers = {}, tabs = {}, searches = {}, preferences = {} }
  local seen = {}
  for _, line in ipairs(vim.fn.readfile(path)) do
    local position, name = line:match('^badd %+(%d+) (.+)$')
    if name and not name:match('^term://') then
      name = session_path(name, root)
      if not seen[name] and vim.fn.filereadable(name) == 1 then
        local key = tostring(#result.buffers + 1); seen[name] = true
        result.buffers[#result.buffers + 1] = { key = key, name = name, modified = false }
        if #result.tabs == 0 then result.tabs[1] = { active = key, layout = { kind = 'leaf', buffer = key,
          width = vim.o.columns, height = vim.o.lines - 3, view = { lnum = tonumber(position), col = 0 } } } end
      end
    end
  end
  return result
end
local function valid(state)
  if type(state) ~= 'table' or state.version ~= 1 or type(state.buffers) ~= 'table' or type(state.tabs) ~= 'table' then return false end
  if state.preferences ~= nil and type(state.preferences) ~= 'table' then return false end
  if state.searches ~= nil and type(state.searches) ~= 'table' then return false end
  for _, name in ipairs({ 'explorer_width', 'terminal_height' }) do
    local value = (state.preferences or {})[name]
    if value ~= nil and (type(value) ~= 'number' or value < 1) then return false end
  end
  for _, value in pairs(state.searches or {}) do
    if type(value) ~= 'table' or type(value.cwd) ~= 'string' or type(value.query) ~= 'string' or type(value.exclude) ~= 'table' then return false end
    for _, pattern in ipairs(value.exclude) do if type(pattern) ~= 'string' then return false end end
  end
  local keys = {}
  for _, item in ipairs(state.buffers) do
    if type(item) ~= 'table' or type(item.key) ~= 'string' or type(item.name) ~= 'string' or keys[item.key] then return false end
    keys[item.key] = true
    if item.fileformat and not vim.tbl_contains({ 'unix', 'dos', 'mac' }, item.fileformat) then return false end
    if item.draft ~= nil then
      if type(item.draft) ~= 'table' or #item.draft == 0 then return false end
      for _, line in ipairs(item.draft) do if type(line) ~= 'string' then return false end end
    end
  end
  local function tree(node, depth)
    if type(node) ~= 'table' or depth > 64 then return false end
    if node.kind == 'leaf' then
      if node.view ~= nil and type(node.view) ~= 'table' then return false end
      for _, value in pairs(node.view or {}) do if type(value) ~= 'number' then return false end end
      return keys[node.buffer] and type(node.width) == 'number' and node.width > 0
        and type(node.height) == 'number' and node.height > 0 and (node.view == nil or type(node.view) == 'table')
    end
    if (node.kind ~= 'row' and node.kind ~= 'col') or type(node.children) ~= 'table' or #node.children < 1 then return false end
    for _, child in ipairs(node.children) do if not tree(child, depth + 1) then return false end end
    return true
  end
  for _, tab in ipairs(state.tabs) do if type(tab) ~= 'table' or not tree(tab.layout, 0) then return false end end
  return true
end
function M.current()
  M.root = M.root or normalize(vim.fn.getcwd())
  if not states[M.root] then
    local value, err = read(filename(M.root))
    if value and not valid(value) then err = 'Unsupported workspace state: ' .. filename(M.root) end
    states[M.root] = err and { blocked = err } or value or { version = 1, root = M.root, searches = {}, preferences = {}, buffers = {}, tabs = {} }
  end
  return states[M.root]
end
function M.preference(name, default, value)
  local state = M.current()
  if state.blocked then return default end
  state.preferences = state.preferences or {}
  if value ~= nil and state.preferences[name] ~= value then state.preferences[name] = value; M.queue() end
  local found = state.preferences[name]
  if found == nil then return default end
  return found
end
function M.search(kind)
  local state = M.current()
  if state.blocked then return { cwd = M.root, exclude = {}, query = '' } end
  state.searches = state.searches or {}
  state.searches[kind] = state.searches[kind] or { cwd = M.root, exclude = {}, query = '' }
  return state.searches[kind]
end
local function disk_hash(path)
  if path == '' then return 'missing' end
  local stat = uv.fs_stat(path)
  if not stat or stat.type ~= 'file' then return 'missing' end
  local fd = uv.fs_open(path, 'r', 0)
  if not fd then return 'unreadable' end
  local data = uv.fs_read(fd, stat.size, 0); uv.fs_close(fd)
  return data and vim.fn.sha256(data) or 'unreadable'
end
local function normal(buf)
  return api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == '' and vim.bo[buf].buflisted
    and not vim.tbl_contains({ 'gitcommit', 'gitrebase' }, vim.bo[buf].filetype)
end
function M.capture_sizes()
  if M.restoring then return end
  local explorer = false
  for _, win in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_get_config(win).relative == '' then
      local buf = api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == 'neo-tree' then
        explorer = true
        M.preference('explorer_width', 32, api.nvim_win_get_width(win))
      elseif vim.b[buf].movim_terminal_panel then
        M.preference('terminal_height', 15, api.nvim_win_get_height(win))
      end
    end
  end
  M.preference('explorer_open', false, explorer)
end
local function layout(node, keys)
  if node[1] == 'leaf' then
    local win = node[2]; local key = keys[api.nvim_win_get_buf(win)]
    if not key then return nil end
    return { kind = 'leaf', buffer = key, width = api.nvim_win_get_width(win), height = api.nvim_win_get_height(win),
      view = api.nvim_win_call(win, vim.fn.winsaveview), wrap = vim.wo[win].wrap }
  end
  local children = {}
  for _, child in ipairs(node[2]) do local value = layout(child, keys); if value then children[#children + 1] = value end end
  if #children == 0 then return nil end
  if #children == 1 then return children[1] end
  return { kind = node[1], children = children }
end
function M.save(force)
  if M.restoring or (M.stopped and not force) then return true end
  local ok, err = pcall(function()
    local state = M.current(); assert(not state.blocked, state.blocked)
    M.capture_sizes()
    local buffers, keys = {}, {}
    for _, buf in ipairs(api.nvim_list_bufs()) do
      if normal(buf) then
        local name = api.nvim_buf_get_name(buf)
        local modified = vim.bo[buf].modified
        local tick = api.nvim_buf_get_changedtick(buf)
        local entry = cache[buf]
        if not entry or entry.name ~= name then entry = { name = name, disk = disk_hash(name) }; cache[buf] = entry end
        if modified or name == '' then
          if entry.tick ~= tick then entry.lines = api.nvim_buf_get_lines(buf, 0, -1, true); entry.tick = tick end
        end
        if name ~= '' or modified or (entry.lines and (#entry.lines > 1 or entry.lines[1] ~= '')) then
          local key = tostring(buf); keys[buf] = key
          buffers[#buffers + 1] = { key = key, name = name, modified = modified, draft = (modified or name == '') and entry.lines or nil,
            disk_hash = entry.disk, filetype = vim.bo[buf].filetype, fileformat = vim.bo[buf].fileformat,
            fileencoding = vim.bo[buf].fileencoding,
            endofline = vim.bo[buf].endofline, recovery_origin = vim.b[buf].movim_recovery_origin }
        end
      end
    end
    local tabs, selected = {}, 1
    for _, tab in ipairs(api.nvim_list_tabpages()) do
      local tree = layout(vim.fn.winlayout(api.nvim_tabpage_get_number(tab)), keys)
      if tree then
        tabs[#tabs + 1] = { layout = tree, active = keys[api.nvim_win_get_buf(api.nvim_tabpage_get_win(tab))] }
        if tab == api.nvim_get_current_tabpage() then selected = #tabs end
      end
    end
    state.buffers, state.tabs, state.selected = buffers, tabs, selected
    state.blocked = nil
    -- No timestamp in the comparison: unchanged events do not touch disk.
    if vim.deep_equal(signatures[M.root], state) then return end
    state.updated = os.time()
    write(filename(M.root), state)
    local list = registry(); list.projects[M.root] = { updated = state.updated }; list.last = M.root
    write(folder() .. '/index.json', list)
    signatures[M.root] = vim.deepcopy(state)
  end)
  if not ok then vim.notify('Workspace save failed: ' .. tostring(err), vim.log.levels.ERROR); return false end
  return true
end
function M.queue()
  if not M.ready or M.restoring or M.stopped then return end
  if pending then pending:stop(); pending:close() end
  local timer = uv.new_timer(); pending = timer
  timer:start(1000, 0, vim.schedule_wrap(function()
    if pending ~= timer then return end
    timer:close(); pending = nil
    M.save()
  end))
end
local function restore_layout(node, win, buffers, leaves)
  if node.kind == 'leaf' then
    local buf = buffers[node.buffer]
    if buf then api.nvim_win_set_buf(win, buf) end
    leaves[#leaves + 1] = { win = win, node = node }
    return
  end
  local windows = { win }
  for i = 2, #node.children do
    api.nvim_set_current_win(windows[i - 1])
    vim.cmd(node.kind == 'row' and 'belowright vsplit' or 'belowright split')
    windows[i] = api.nvim_get_current_win()
  end
  for i, child in ipairs(node.children) do restore_layout(child, windows[i], buffers, leaves) end
end
function M.open(path, options)
  options = options or {}; path = normalize(path)
  if vim.fn.isdirectory(path) == 0 then vim.notify('Project folder does not exist: ' .. path, vim.log.levels.ERROR); return false end
  local target, failure = read(filename(path))
  if failure or (target and not valid(target)) then
    vim.notify(failure or ('Unsupported workspace: ' .. filename(path)), vim.log.levels.ERROR); return false
  end
  if not options.startup and not M.save(true) then return false end
  if path == M.root and not options.startup then target = read(filename(path)) end
  local previous = registry().projects[path]
  if not target and previous and previous.legacy then target = import_legacy(previous.legacy, path) end
  M.restoring = true
  local equalalways = vim.o.equalalways; vim.o.equalalways = false
  local ok, err = pcall(function()
    if package.loaded['utils.terminal_panel'] then package.loaded['utils.terminal_panel'].hide() end
    if package.loaded['utils.find_panel'] then package.loaded['utils.find_panel'].close() end
    local previous = api.nvim_list_bufs()
    -- Keep a real editor window while closing panels; Neo-tree may quit if it
    -- temporarily becomes the last window during a project switch.
    for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
      if api.nvim_win_get_config(win).relative == '' and normal(api.nvim_win_get_buf(win)) then api.nvim_set_current_win(win); break end
    end
    local empty = api.nvim_create_buf(true, false); api.nvim_win_set_buf(0, empty)
    vim.cmd('silent! tabonly!'); vim.cmd('silent! only!')
    for _, buf in ipairs(previous) do
      if normal(buf) then api.nvim_buf_delete(buf, { force = true }) end
    end
    vim.cmd('cd ' .. vim.fn.fnameescape(path)); M.root = path
    states[path] = target or nil
    local state = M.current(); local buffers, leaves, conflicts = {}, {}, {}
    for _, item in ipairs(state.buffers) do
      local name = item.name
      local conflict = item.draft and name ~= '' and item.disk_hash ~= disk_hash(name)
      local buf
      if name ~= '' and not conflict then
        buf = vim.fn.bufadd(name); vim.fn.bufload(buf); vim.bo[buf].buflisted = true
      else buf = api.nvim_create_buf(true, false) end
      buffers[item.key] = buf
      if item.draft then
        api.nvim_buf_set_lines(buf, 0, -1, false, item.draft)
        vim.bo[buf].fileformat = item.fileformat or 'unix'; vim.bo[buf].endofline = item.endofline ~= false
        vim.bo[buf].fileencoding = item.fileencoding or ''
        vim.bo[buf].modified = item.modified or name == '' or conflict
      end
      if item.filetype and item.filetype ~= '' then vim.bo[buf].filetype = item.filetype end
      vim.b[buf].movim_recovery_origin = conflict and name or item.recovery_origin
      if conflict then conflicts[#conflicts + 1] = name end
      cache[buf] = { name = api.nvim_buf_get_name(buf), disk = conflict and 'missing' or disk_hash(name) }
    end
    local tabs = {}
    for i, tab in ipairs(state.tabs) do
      if i > 1 then vim.cmd('tab split') end
      tabs[i] = api.nvim_get_current_tabpage()
      restore_layout(tab.layout, api.nvim_get_current_win(), buffers, leaves)
      for _, leaf in ipairs(leaves) do
        if api.nvim_win_get_tabpage(leaf.win) == tabs[i] and leaf.node.buffer == tab.active then api.nvim_set_current_win(leaf.win); break end
      end
    end
    if #state.tabs == 0 and #state.buffers > 0 then api.nvim_win_set_buf(0, buffers[state.buffers[1].key]) end
    if tabs[state.selected or 1] then api.nvim_set_current_tabpage(tabs[state.selected or 1]) end
    for _, leaf in ipairs(leaves) do
      pcall(api.nvim_win_set_width, leaf.win, leaf.node.width)
      pcall(api.nvim_win_set_height, leaf.win, leaf.node.height)
      api.nvim_win_call(leaf.win, function() vim.wo.wrap = leaf.node.wrap or false; vim.fn.winrestview(leaf.node.view or {}) end)
    end
    if api.nvim_buf_is_valid(empty) and #vim.fn.win_findbuf(empty) == 0 then api.nvim_buf_delete(empty, { force = true }) end
    local width = state.preferences and state.preferences.explorer_width
    if width and state.preferences.explorer_open then
      local win = api.nvim_get_current_win()
      pcall(function() require('neo-tree.command').execute({ action = 'show', position = 'left', dir = path }) end)
      if api.nvim_win_is_valid(win) then api.nvim_set_current_win(win) end
    end
    if #conflicts > 0 then vim.notify('Disk files changed since the draft was saved. Recovered drafts are unnamed; originals were preserved:\n' .. table.concat(conflicts, '\n'), vim.log.levels.WARN) end
  end)
  vim.o.equalalways = equalalways; M.restoring = false; M.ready = true
  if not ok then vim.notify('Workspace restore failed: ' .. tostring(err), vim.log.levels.ERROR); return false end
  local list = registry(); list.last = path; list.projects[path] = { updated = os.time() }
  local saved, failure = pcall(write, folder() .. '/index.json', list)
  if not saved then vim.notify('Could not update workspace index: ' .. tostring(failure), vim.log.levels.ERROR) end
  M.queue(); return true
end
function M.select()
  local projects = {}
  for root, item in pairs(registry().projects) do
    if vim.fn.isdirectory(root) == 1 then projects[#projects + 1] = { root = root, updated = item.updated or 0 } end
  end
  table.sort(projects, function(a, b) return a.updated > b.updated end)
  vim.ui.select(projects, { prompt = 'Open project workspace', format_item = function(item) return vim.fn.fnamemodify(item.root, ':~') end },
    function(item) if item then M.open(item.root) end end)
end
function M.setup(options)
  options = options or {}; M.directory = options.directory; M.root = normalize(vim.fn.getcwd())
  M.legacy_directory = options.legacy_directory
  if not options.directory then M.legacy_directory = vim.fn.stdpath('state') .. '/sessions' end
  local group = api.nvim_create_augroup('movim-workspaces', { clear = true })
  api.nvim_create_autocmd('BufReadPost', { group = group, callback = function(args)
    if normal(args.buf) then cache[args.buf] = { name = api.nvim_buf_get_name(args.buf), disk = disk_hash(api.nvim_buf_get_name(args.buf)) } end
  end })
  api.nvim_create_autocmd('BufWritePost', { group = group, callback = function(args)
    if normal(args.buf) then cache[args.buf] = { name = api.nvim_buf_get_name(args.buf), disk = disk_hash(api.nvim_buf_get_name(args.buf)) } end
  end })
  api.nvim_create_autocmd('DirChanged', { group = group, callback = function()
    if M.restoring or not M.ready then return end
    if M.save() then M.root = normalize(vim.fn.getcwd()); M.queue() end
  end })
  api.nvim_create_autocmd('BufWipeout', { group = group, callback = function(args) cache[args.buf] = nil; M.queue() end })
  api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'BufEnter', 'BufWritePost', 'WinClosed', 'TabClosed', 'CursorHold' }, { group = group, callback = M.queue })
  api.nvim_create_autocmd('WinResized', { group = group, callback = function() M.capture_sizes(); M.queue() end })
  api.nvim_create_autocmd({ 'FocusLost', 'VimLeavePre' }, { group = group, callback = function() if M.ready then M.save() end end })
  api.nvim_create_autocmd('VimEnter', { group = group, once = true, callback = function()
    vim.schedule(function()
      -- Installer and CLI checks must never replace an interactive workspace.
      if #api.nvim_list_uis() == 0 and options.auto_restore ~= false then return end
      if options.auto_restore ~= false and #api.nvim_list_uis() > 0 and vim.fn.argc() == 0 then
        -- Launchers may start in Documents or a previously visited folder.
        -- With no explicit project argument, the last active project wins.
        local root = registry().last
        if vim.env.MOVIM_PROJECT_DIR and vim.env.MOVIM_PROJECT_DIR ~= '' then root = normalize(vim.env.MOVIM_PROJECT_DIR) end
        if root then M.open(root, { startup = true }) end
      end
      M.ready = true
    end)
  end })
  if options.auto_restore == false then M.ready = true end
  api.nvim_create_user_command('Workspaces', M.select, { force = true })
  api.nvim_create_user_command('WorkspaceSave', function() if M.save(true) then vim.notify('Workspace saved') end end, { force = true })
  api.nvim_create_user_command('WorkspaceOpen', function(args)
    if args.args ~= '' then M.open(vim.fn.expand(args.args)); return end
    vim.ui.input({ prompt = 'Project folder: ', completion = 'dir' }, function(path) if path and path ~= '' then M.open(vim.fn.expand(path)) end end)
  end, { nargs = '?', complete = 'dir', force = true })
  api.nvim_create_user_command('WorkspaceLast', function() local last = registry().last; if last then M.open(last) end end, { force = true })
  api.nvim_create_user_command('WorkspaceQuit', function() if M.save(true) then vim.cmd('qa!') end end, { force = true })
  vim.keymap.set('n', '<leader>qp', M.select, { desc = 'Choose project workspace' })
  vim.keymap.set('n', '<leader>qs', function() M.open(M.root) end, { desc = 'Restore project workspace' })
  vim.keymap.set('n', '<leader>ql', '<cmd>WorkspaceLast<CR>', { desc = 'Restore last project workspace' })
  vim.keymap.set('n', '<leader>qS', '<cmd>WorkspaceSave<CR>', { desc = 'Save workspace now' })
  vim.keymap.set('n', '<leader>qq', '<cmd>WorkspaceQuit<CR>', { desc = 'Save workspace drafts and quit' })
  vim.keymap.set('n', '<leader>qd', function() M.stopped = true; vim.notify('Workspace autosave paused for this run') end, { desc = 'Pause workspace saving' })
end
return M
