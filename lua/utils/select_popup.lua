local M = {}

function M.select(items, opts, callback)
  opts = opts or {}
  local actions = require('telescope.actions')
  local state = require('telescope.actions.state')
  local finished = false
  local function finish(value, index)
    if finished then return end
    finished = true
    vim.schedule(function() callback(value, index) end)
  end
  if #items == 0 then finish(nil); return end
  local entries = {}
  for index, item in ipairs(items) do
    entries[index] = { value = item, index = index,
      label = tostring(opts.format_item and opts.format_item(item) or item):gsub('[\r\n]', ' ') }
  end
  require('telescope.pickers').new(require('telescope.themes').get_dropdown({
    prompt_title = (opts.prompt or 'Choose an option'):gsub('[:%s]+$', ''),
    results_title = 'Enter select  /  Esc cancel',
    previewer = false,
    initial_mode = 'insert',
    prompt_prefix = '  ', selection_caret = '> ',
    layout_config = { anchor = 'CENTER', width = function(_, columns) return math.min(90, columns - 4) end,
      height = function(_, _, lines) return math.min(math.max(#items, 3), 12, math.max(1, lines - 8)) end },
  }), {
    finder = require('telescope.finders').new_table({ results = entries, entry_maker = function(entry)
      return { value = entry.value, index = entry.index, display = entry.label, ordinal = entry.label }
    end }),
    sorter = require('telescope.config').values.generic_sorter({}),
    attach_mappings = function(buf, map)
      local function accept()
        if finished then return end
        local entry = state.get_selected_entry()
        if not entry then return end
        finished = true
        actions.close(buf)
        vim.schedule(function() callback(entry.value, entry.index) end)
      end
      local function cancel() finish(nil); actions.close(buf) end
      actions.select_default:replace(accept)
      for _, mode in ipairs({ 'i', 'n' }) do
        map(mode, '<Esc>', cancel)
        map(mode, '<C-c>', cancel)
        map(mode, '<2-LeftMouse>', accept)
      end
      vim.api.nvim_create_autocmd('BufWipeout', { buffer = buf, once = true, callback = function() finish(nil) end })
      return true
    end,
  }):find()
end

return M
