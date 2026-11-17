-- Persistent per-workspace name filters, using Neo-tree's native filtering.
local M = {}
local function patterns() return require('utils.workspace').preference('explorer_hidden', {}) end
local function compile(glob)
  return '^' .. glob:gsub('([%^%$%(%)%%%.%[%]%+%-])', '%%%1'):gsub('%*', '.*'):gsub('%?', '.') .. '$'
end
function M.apply(state)
  if state.name ~= 'filesystem' then return end
  if not state.movim_original_patterns then state.movim_original_patterns = vim.deepcopy(state.filtered_items.hide_by_pattern or {}) end
  state.filtered_items.hide_by_pattern = vim.deepcopy(state.movim_original_patterns)
  for _, name in ipairs(patterns()) do table.insert(state.filtered_items.hide_by_pattern, compile(name)) end
end
function M.refresh(rescan)
  if not package.loaded['neo-tree'] then return end
  local manager = require('neo-tree.sources.manager')
  manager._for_each_state('filesystem', function(state) M.apply(state); state.dirty = true end)
  if rescan ~= false then manager.refresh('filesystem') end
end
local function save(values)
  require('utils.workspace').preference('explorer_hidden', {}, values)
  M.refresh()
end
function M.hide(state)
  local node = state.tree:get_node()
  if not node or node:get_id() == state.path or node.type == 'message' then return end
  local values = vim.deepcopy(patterns())
  if not vim.tbl_contains(values, node.name) then values[#values + 1] = node.name end
  save(values)
end
function M.edit()
  vim.ui.input({ prompt = 'Hidden names/globs (comma-separated; empty resets): ', default = table.concat(patterns(), ', ') }, function(value)
    if value == nil then return end
    local values = {}
    for _, name in ipairs(vim.split(value, ',', { plain = true, trimempty = true })) do
      name = vim.trim(name)
      if name:find('[/\\]') then return vim.notify('Use names or globs, e.g. dist, *.log (not paths)', vim.log.levels.WARN) end
      if name ~= '' and not vim.tbl_contains(values, name) then values[#values + 1] = name end
    end
    save(values)
  end)
end
return M
