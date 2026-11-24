-- One persistent search state per picker and project, including scope controls.
local M = {}
local originals = {}
local paste_chunks
local function workspace() return require('utils.workspace') end
local function directory(value, base)
  local path = vim.fn.expand(vim.trim(value))
  if path == '' then return nil end
  if not path:match('^%a:[/\\]') and not path:match('^[/\\]') then path = base .. '/' .. path end
  path = vim.fs.normalize(vim.fn.fnamemodify(path, ':p'))
  return (path == '/' or path:match('^%a:/$')) and path or path:gsub('/$', '')
end
local function folders(state, done)
  local dirs = vim.deepcopy(state.dirs or { state.cwd })
  for index, path in ipairs(dirs) do dirs[index] = directory(path, state.cwd) end
  local show
  show = function()
    local choices = { 'Add folder…', 'Apply folders' }
    for _, path in ipairs(dirs) do choices[#choices + 1] = 'Remove: ' .. path end
    vim.ui.select(choices, { prompt = 'Search folders (' .. #dirs .. ')' }, function(_, index)
      if not index then return done() end
      if index == 1 then
        vim.ui.input({ prompt = 'Add search folder: ', default = state.cwd .. '/', completion = 'dir' }, function(value)
          if value then
            local path = directory(value, state.cwd)
            if path and vim.fn.isdirectory(path) == 1 then
              local duplicate = false
              for _, existing in ipairs(dirs) do
                if (vim.fn.has('win32') == 1 and existing:lower() == path:lower()) or existing == path then duplicate = true end
              end
              if not duplicate then dirs[#dirs + 1] = path end
            else vim.notify('Search folder does not exist: ' .. (path or value), vim.log.levels.WARN) end
          end
          vim.schedule(show)
        end)
      elseif index == 2 then
        if #dirs == 0 then vim.notify('Add at least one search folder', vim.log.levels.WARN); return vim.schedule(show) end
        state.dirs = dirs
        state.cwd = #dirs == 1 and dirs[1] or workspace().root or state.cwd
        done()
      else table.remove(dirs, index - 2); vim.schedule(show) end
    end)
  end
  show()
end
function M.open(kind, options)
  local state = options and options._movim_state or workspace().search(kind)
  options = vim.deepcopy(options or {})
  options._movim_state = nil
  state.kind = kind
  if options.cwd then state.cwd = directory(options.cwd, vim.fn.getcwd()); state.dirs = { state.cwd } end
  if vim.fn.isdirectory(state.cwd or '') == 0 then state.cwd = workspace().root or vim.fn.getcwd() end
  if options.default_text ~= nil then state.query = options.default_text end
  options.cwd, options.default_text = state.cwd, state.query or ''
  if options.search_dirs then
    state.dirs = {}
    for _, path in ipairs(options.search_dirs) do state.dirs[#state.dirs + 1] = directory(path, state.cwd) end
  end
  options.search_dirs = {}
  local dirs = state.dirs and #state.dirs > 0 and state.dirs or { state.cwd }
  for index, path in ipairs(dirs) do
    local normalized = directory(path, state.cwd)
    local key = vim.fn.has('win32') == 1 and normalized:lower() or normalized
    local covered = false
    for other, parent in ipairs(dirs) do
      parent = directory(parent, state.cwd)
      parent = vim.fn.has('win32') == 1 and parent:lower() or parent
      local prefix = parent:gsub('/$', '') .. '/'
      if other ~= index and (key:sub(1, #prefix) == prefix or (key == parent and other < index)) then covered = true; break end
    end
    if not covered then options.search_dirs[#options.search_dirs + 1] = normalized end
  end
  local attach = options.attach_mappings
  options.attach_mappings = function(bufnr, map)
    M.attach(bufnr, map, state, kind)
    return not attach or attach(bufnr, map) ~= false
  end
  local args = { '--glob', '!.movim/**' }
  for _, pattern in ipairs(state.exclude or {}) do args[#args + 1] = '--glob'; args[#args + 1] = '!' .. pattern end
  if kind == 'grep' then
    if state.literal then args[#args + 1] = '--fixed-strings' end
    if state.multiline then args[#args + 1] = '--multiline' end
    local additional = options.additional_args
    if type(additional) == 'function' then additional = additional(options) end
    vim.list_extend(args, additional or {})
    options.additional_args = args
    options.prompt_title = options.prompt_title or 'Live Grep | Ctrl+D: folders | Ctrl+E: edit | Ctrl+X: exclude'
  else
    local command = { 'rg', '--files', '--hidden', '--glob', '!.git/' }
    vim.list_extend(command, args)
    options.find_command = options.find_command or command
    options.prompt_title = options.prompt_title or 'Find Files | Ctrl+D: folders | Ctrl+E: edit | Ctrl+X: exclude'
  end
  workspace().queue()
  return originals[kind](options)
end
function M.attach(prompt_bufnr, map, state, kind)
  vim.b[prompt_bufnr].movim_search_prompt = true
  local actions, action_state = require('telescope.actions'), require('telescope.actions.state')
  local picker = action_state.get_current_picker(prompt_bufnr)
  require('utils.search_clear').telescope(prompt_bufnr, map)
  state = state or workspace().search(kind or 'files'); state.kind = kind or state.kind or 'files'
  require('utils.search_folders').attach(picker, state.dirs and #state.dirs > 0 and state.dirs or { state.cwd })
  local function remember()
    if vim.api.nvim_buf_is_valid(prompt_bufnr) then
      local ok, query = pcall(picker._get_prompt, picker)
      if ok then state.query = query; workspace().queue() end
    end
  end
  vim.api.nvim_buf_attach(prompt_bufnr, false, { on_lines = remember, on_detach = function() workspace().queue() end })
  local function edit_scope(what)
    remember()
    actions.close(prompt_bufnr)
    vim.schedule(function()
      local function done()
        workspace().queue()
        vim.schedule(function() M.open(state.kind, { _movim_state = state }) end)
      end
      if what == 'folder' then return folders(state, done) end
      vim.ui.input({ prompt = 'Exclude patterns (comma-separated): ',
        default = table.concat(state.exclude or {}, ', ') }, function(value)
        if value ~= nil then
          state.exclude = {}
          for _, pattern in ipairs(vim.split(value, ',', { plain = true, trimempty = true })) do
            pattern = vim.trim(pattern):gsub('\\', '/'):gsub('^!', '')
            if pattern ~= '' then state.exclude[#state.exclude + 1] = pattern end
          end
        end
        done()
      end)
    end)
  end
  for _, mode in ipairs({ 'i', 'n' }) do
    map(mode, '<C-d>', function() edit_scope('folder') end)
    map(mode, '<C-x>', function() edit_scope('exclude') end)
    map(mode, '<C-e>', function()
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(prompt_bufnr) then require('utils.search_preview').edit(prompt_bufnr) end
      end)
    end)
  end
  return true
end
function M.selection(kind)
  kind = kind or 'grep'
  local mode = vim.fn.mode()
  assert(mode == 'v' or mode == 'V' or mode == '\22', 'Select text first')
  local lines = vim.fn.getregion(vim.fn.getpos('v'), vim.fn.getpos('.'), { type = mode })
  local text = table.concat(lines, '\n')
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'nx', false)
  if kind == 'buffer' then return require('utils.find_panel').open({ default_text = text:gsub('\n', [[\n]]), multiline = #lines > 1 }) end
  if kind == 'files' then return require('telescope.builtin').find_files({ default_text = text:gsub('\n', ' ') }) end
  local state = workspace().search('grep')
  state.literal, state.multiline = #lines == 1, #lines > 1
  if #lines > 1 then text = vim.fn.escape(text, [[\.^$*+?()[]{}|]]):gsub('\n', [[\n]]) end
  require('telescope.builtin').live_grep({ default_text = text })
end
function M.install()
  local builtin = require('telescope.builtin')
  if originals.files then return end
  originals.files, originals.grep = builtin.find_files, builtin.live_grep
  local paste = vim.paste
  vim.paste = function(lines, phase)
    if phase == 1 then paste_chunks = nil end
    if paste_chunks or vim.b.movim_search_prompt then
      if phase == -1 then return paste({ table.concat(lines, ' ') }, -1) end
      if phase == 1 then paste_chunks = { buffer = vim.api.nvim_get_current_buf(), lines = {} } end
      if paste_chunks and paste_chunks.buffer == vim.api.nvim_get_current_buf() then
        local chunks = paste_chunks.lines
        if #chunks > 0 and #lines > 0 then chunks[#chunks] = chunks[#chunks] .. table.remove(lines, 1) end
        vim.list_extend(chunks, lines)
        if phase == 3 then
          paste_chunks = nil
          return paste({ table.concat(chunks, ' ') }, -1)
        end
        return true
      end
      paste_chunks = nil
    end
    return paste(lines, phase)
  end
  builtin.find_files = function(opts) return M.open('files', opts) end
  builtin.live_grep = function(opts) return M.open('grep', opts) end
end
return M
