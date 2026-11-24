local M = {}
local api = vim.api
local loaded = {}
local loaded_root
local registered = {}
local builtins = {
  { abbreviation = 'log', description = 'Log a value', filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'vue', 'svelte' }, body = 'console.log($VALUE$);$END$', variables = { VALUE = 'value' } },
  { abbreviation = 'fn', description = 'Named function', filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' }, body = 'function $NAME$($PARAMS$) {\n\t$END$\n}', variables = { NAME = 'name', PARAMS = '' } },
  { abbreviation = 'afn', description = 'Arrow function', filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' }, body = 'const $NAME$ = ($PARAMS$) => {\n\t$END$\n};', variables = { NAME = 'name', PARAMS = '' } },
  { abbreviation = 'fori', description = 'Indexed loop', filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' }, body = 'for (let $INDEX$ = 0; $INDEX$ < $LIMIT$; $INDEX$++) {\n\t$END$\n}', variables = { INDEX = 'i', LIMIT = 'length' } },
  { abbreviation = 'foreach', description = 'Array iteration', filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' }, body = '$ARRAY$.forEach(($ITEM$) => {\n\t$END$\n});', variables = { ARRAY = 'items', ITEM = 'item' } },
  { abbreviation = 'if', description = 'Conditional / surround selection', filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' }, body = 'if ($CONDITION$) {\n\t$SELECTION$$END$\n}', variables = { CONDITION = 'condition' } },
  { abbreviation = 'try', description = 'Try / catch', filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' }, body = 'try {\n\t$SELECTION$$END$\n} catch ($ERROR$) {\n\tconsole.error($ERROR$);\n}', variables = { ERROR = 'error' } },
  { abbreviation = 'imp', description = 'Named import', filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' }, body = "import { $NAME$ } from '$MODULE$';$END$", variables = { NAME = 'name', MODULE = 'module' } },
  { abbreviation = 'rfc', description = 'React function component', filetypes = { 'javascriptreact', 'typescriptreact' }, body = 'export default function $NAME$() {\n\treturn (\n\t\t$END$\n\t);\n}', variables = { NAME = 'Component' } },
  { abbreviation = 'interface', description = 'TypeScript interface', filetypes = { 'typescript', 'typescriptreact' }, body = 'interface $NAME$ {\n\t$END$\n}', variables = { NAME = 'Name' } },
  { abbreviation = 'div', description = 'HTML container', filetypes = { 'html', 'htmlangular', 'vue', 'svelte' }, body = '<div class="$CLASS$">\n\t$SELECTION$$END$\n</div>', variables = { CLASS = 'container' } },
  { abbreviation = 'fn', description = 'Lua function', filetypes = { 'lua' }, body = 'local function $NAME$($PARAMS$)\n\t$END$\nend', variables = { NAME = 'name', PARAMS = '' } },
  { abbreviation = 'def', description = 'Python function', filetypes = { 'python' }, body = 'def $NAME$($PARAMS$):\n\t$END$', variables = { NAME = 'name', PARAMS = '' } },
}
function M.path()
  return (require('utils.workspace').root or vim.fn.getcwd()) .. '/.movim/live-templates.json'
end
local function compile(item)
  local numbers, next_number = {}, 0
  local body = type(item.body) == 'table' and table.concat(item.body, '\n') or item.body
  return (body:gsub('%$([%u_][%u%d_]*)%$', function(name)
    if name == 'END' then return '$0' end
    if name == 'SELECTION' then return '${TM_SELECTED_TEXT}' end
    if numbers[name] then return '$' .. numbers[name] end
    next_number = next_number + 1
    numbers[name] = next_number
    local default = tostring((item.variables or {})[name] or ''):gsub('\\', '\\\\'):gsub('%$', '\\$'):gsub('}', '\\}')
    return '${' .. next_number .. ':' .. default .. '}'
  end))
end
local function validate(value)
  assert(type(value) == 'table' and type(value.templates) == 'table' and vim.islist(value.templates), 'Expected a templates array')
  assert(value.enabled == nil or type(value.enabled) == 'boolean', 'enabled must be true or false')
  local keys = {}
  for _, item in ipairs(value.templates) do
    assert(type(item) == 'table' and type(item.abbreviation) == 'string' and item.abbreviation:match('^[%w_.%-]+$'), 'Invalid template abbreviation')
    assert(item.disabled == true or type(item.body) == 'string' or (type(item.body) == 'table' and vim.islist(item.body)), 'Template body must be text or lines')
    if type(item.body) == 'table' then for _, line in ipairs(item.body) do assert(type(line) == 'string', 'Template lines must be text') end end
    assert(type(item.filetypes) == 'table' and vim.islist(item.filetypes) and #item.filetypes > 0, 'Template needs filetypes')
    assert(item.disabled == nil or type(item.disabled) == 'boolean', 'disabled must be true or false')
    assert(item.description == nil or type(item.description) == 'string', 'description must be text')
    assert(item.variables == nil or type(item.variables) == 'table', 'variables must be an object')
    for name, default in pairs(item.variables or {}) do assert(type(name) == 'string' and type(default) == 'string', 'Variable defaults must be text') end
    for _, ft in ipairs(item.filetypes) do
      assert(type(ft) == 'string' and ft:match('^[%w_]+$'), 'Invalid filetype')
      local key = ft .. ':' .. item.abbreviation
      assert(not keys[key], 'Duplicate template: ' .. key)
      keys[key] = true
    end
  end
  return value
end
function M.reload()
  local path = M.path()
  local root = vim.fs.dirname(path)
  local function reject(reason)
    if root ~= loaded_root then
      for ft in pairs(registered) do require('luasnip').add_snippets(ft, {}, { key = 'movim-project-' .. ft }) end
      loaded = {}; loaded_root = root
    end
    vim.schedule(function() vim.notify('Live templates: ' .. tostring(reason), vim.log.levels.ERROR) end)
    return false
  end
  local ok, config = pcall(function()
    if vim.fn.filereadable(path) == 0 then return { templates = {} } end
    return validate(vim.json.decode(table.concat(vim.fn.readfile(path), '\n')))
  end)
  if not ok then return reject(config) end
  local combined = {}
  if config.enabled ~= false then
    for _, item in ipairs(builtins) do
      for _, ft in ipairs(item.filetypes) do combined[ft .. ':' .. item.abbreviation] = { item = item, ft = ft } end
    end
    for _, item in ipairs(config.templates) do
      for _, ft in ipairs(item.filetypes) do
        if item.disabled then combined[ft .. ':' .. item.abbreviation] = nil
        else combined[ft .. ':' .. item.abbreviation] = { item = item, ft = ft } end
      end
    end
  end
  local ls = require('luasnip')
  local parsed, entries = {}, {}
  ok, config = pcall(function()
    for _, key in ipairs(vim.tbl_keys(combined)) do
      local entry = combined[key]
      local item, ft = entry.item, entry.ft
      local snippet = ls.parser.parse_snippet({ trig = item.abbreviation, name = item.description or item.abbreviation,
        dscr = item.description or item.abbreviation, priority = 2500 }, compile(item))
      parsed[ft] = parsed[ft] or {}; parsed[ft][#parsed[ft] + 1] = snippet
      entries[#entries + 1] = { abbreviation = item.abbreviation, description = item.description or item.abbreviation,
        body = item.body, ft = ft, snippet = snippet }
    end
  end)
  if not ok then return reject(config) end
  for ft in pairs(registered) do ls.add_snippets(ft, parsed[ft] or {}, { key = 'movim-project-' .. ft }) end
  for ft, snippets in pairs(parsed) do
    if not registered[ft] then ls.add_snippets(ft, snippets, { key = 'movim-project-' .. ft }) end
    registered[ft] = true
  end
  loaded, loaded_root = entries, root
  return true
end
function M.list(ft)
  if loaded_root ~= vim.fs.dirname(M.path()) then M.reload() end
  ft = ft or vim.bo.filetype
  local entries = {}
  for _, item in ipairs(loaded) do if item.ft == ft or item.ft == 'all' then entries[#entries + 1] = item end end
  table.sort(entries, function(first, second) return first.abbreviation < second.abbreviation end)
  return entries
end
function M.expand(probe)
  local cursor = api.nvim_win_get_cursor(0)
  local before = api.nvim_get_current_line():sub(1, cursor[2])
  for _, item in ipairs(M.list()) do
    local trigger = item.abbreviation
    if before:sub(-#trigger) == trigger and not before:sub(-#trigger - 1, -#trigger - 1):match('[%w_]') then
      if probe then return true end
      require('luasnip').snip_expand(item.snippet, { clear_region = {
        from = { cursor[1] - 1, cursor[2] - #trigger }, to = { cursor[1] - 1, cursor[2] } } })
      return true
    end
  end
  return false
end
function M.pick(selection)
  local win, buf, cursor = api.nvim_get_current_win(), api.nvim_get_current_buf(), api.nvim_win_get_cursor(0)
  local region
  if selection then
    if vim.fn.mode() == '\22' then
      return vim.notify('Live templates support character or line selections. Use v or V.', vim.log.levels.WARN)
    end
    local positions = vim.fn.getregionpos(vim.fn.getpos('v'), vim.fn.getpos('.'), { type = vim.fn.mode() })
    selection = vim.fn.getregion(vim.fn.getpos('v'), vim.fn.getpos('.'), { type = vim.fn.mode() })
    if #positions > 0 then
      local first, last = positions[1][1], positions[#positions][2]
      local text = api.nvim_buf_get_lines(buf, last[2] - 1, last[2], false)[1] or ''
      local col = math.min(last[3] - 1, #text)
      local char = vim.fn.strcharpart(text:sub(col + 1), 0, 1)
      region = { from = { first[2] - 1, first[3] - 1 }, to = { last[2] - 1, math.min(#text, col + #char) } }
    end
    api.nvim_feedkeys(api.nvim_replace_termcodes('<Esc>', true, false, true), 'nx', false)
  end
  local entries = M.list(vim.bo[buf].filetype)
  if #entries == 0 then return vim.notify('No live templates for ' .. vim.bo[buf].filetype .. '. Use :LiveTemplatesEdit to add one.') end
  vim.ui.select(entries, { prompt = 'Live templates', format_item = function(item) return item.abbreviation .. '  ·  ' .. item.description end }, function(item)
    if not item or not api.nvim_win_is_valid(win) or api.nvim_win_get_buf(win) ~= buf then return end
    api.nvim_set_current_win(win)
    api.nvim_win_set_cursor(win, cursor)
    vim.cmd('startinsert')
    require('luasnip').snip_expand(item.snippet, { clear_region = region,
      pos = region and region.from or { cursor[1] - 1, cursor[2] }, expand_params = { env_override = { TM_SELECTED_TEXT = selection or '' } } })
  end)
end
function M.edit()
  local path = M.path()
  if vim.fn.filereadable(path) == 0 then
    vim.fn.mkdir(vim.fs.dirname(path), 'p')
    local config = { enabled = true, templates = { { abbreviation = 'hello', description = 'Project greeting',
      filetypes = { 'javascript', 'typescript' }, body = 'console.log($MESSAGE$);$END$', variables = { MESSAGE = '"Hello"' } } } }
    vim.fn.writefile({ vim.json.encode(config) }, path)
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
  vim.bo.filetype = 'json'
end
function M.setup()
  local group = api.nvim_create_augroup('MovimLiveTemplates', { clear = true })
  api.nvim_create_autocmd({ 'BufEnter', 'FileType' }, { group = group, callback = function()
    if package.loaded.luasnip and loaded_root ~= vim.fs.dirname(M.path()) then M.reload() end
  end })
  api.nvim_create_autocmd('BufWritePost', { group = group, pattern = 'live-templates.json', callback = function(args)
    if vim.fs.normalize(api.nvim_buf_get_name(args.buf)) == vim.fs.normalize(M.path()) then M.reload() end
  end })
  api.nvim_create_user_command('LiveTemplates', function() M.pick() end, { desc = 'Insert project live template' })
  api.nvim_create_user_command('LiveTemplatesEdit', M.edit, { desc = 'Edit .movim/live-templates.json' })
  api.nvim_create_user_command('LiveTemplatesReload', M.reload, { desc = 'Reload project live templates' })
  vim.keymap.set('n', '<leader>ct', function() M.pick() end, { desc = 'Insert live template' })
  vim.keymap.set('i', '<C-j>', function() M.pick() end, { desc = 'Insert live template' })
  vim.keymap.set('x', '<leader>ct', function() M.pick(true) end, { desc = 'Surround selection with live template' })
  vim.keymap.set('n', '<leader>cT', M.edit, { desc = 'Edit project live templates' })
end
return M
