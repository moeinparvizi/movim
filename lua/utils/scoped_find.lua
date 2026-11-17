-- One persistent search state per picker and project, including scope controls.
local M = {}
local originals = {}
local function workspace() return require('utils.workspace') end
function M.open(kind, options)
  local state = options and options._movim_state or workspace().search(kind)
  options = vim.deepcopy(options or {})
  options._movim_state = nil
  state.kind = kind
  if options.cwd then state.cwd = vim.fn.fnamemodify(options.cwd, ':p') end
  if vim.fn.isdirectory(state.cwd or '') == 0 then state.cwd = workspace().root or vim.fn.getcwd() end
  if options.default_text ~= nil then state.query = options.default_text end
  options.cwd, options.default_text = state.cwd, state.query or ''
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
    options.prompt_title = options.prompt_title or 'Live Grep | Ctrl+D: folder | Ctrl+X: exclude'
  else
    local command = { 'rg', '--files', '--hidden', '--glob', '!.git/' }
    vim.list_extend(command, args)
    options.find_command = options.find_command or command
    options.prompt_title = options.prompt_title or 'Find Files | Ctrl+D: folder | Ctrl+X: exclude'
  end
  workspace().queue()
  return originals[kind](options)
end
function M.attach(prompt_bufnr, map, state, kind)
  local actions, action_state = require('telescope.actions'), require('telescope.actions.state')
  local picker = action_state.get_current_picker(prompt_bufnr)
  require('utils.search_clear').telescope(prompt_bufnr, map)
  state = state or workspace().search(kind or 'files'); state.kind = kind or state.kind or 'files'
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
      local folder = what == 'folder'
      vim.ui.input({ prompt = folder and 'Search folder: ' or 'Exclude patterns (comma-separated): ',
        default = folder and state.cwd or table.concat(state.exclude or {}, ', '), completion = folder and 'dir' or nil }, function(value)
        if value ~= nil then
          if folder then
            local path = vim.fn.expand(vim.trim(value))
            if path ~= '' and not path:match('^%a:[/\\]') and not path:match('^[/\\]') then path = state.cwd .. '/' .. path end
            if path ~= '' and vim.fn.isdirectory(path) == 1 then state.cwd = vim.fn.fnamemodify(path, ':p')
            else vim.notify('Search folder does not exist: ' .. path, vim.log.levels.WARN) end
          else
            state.exclude = {}
            for _, pattern in ipairs(vim.split(value, ',', { plain = true, trimempty = true })) do
              pattern = vim.trim(pattern):gsub('\\', '/'):gsub('^!', '')
              if pattern ~= '' then state.exclude[#state.exclude + 1] = pattern end
            end
          end
        end
        workspace().queue()
        vim.schedule(function() M.open(state.kind, { _movim_state = state }) end)
      end)
    end)
  end
  for _, mode in ipairs({ 'i', 'n' }) do
    map(mode, '<C-d>', function() edit_scope('folder') end)
    map(mode, '<C-x>', function() edit_scope('exclude') end)
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
  builtin.find_files = function(opts) return M.open('files', opts) end
  builtin.live_grep = function(opts) return M.open('grep', opts) end
end
return M
