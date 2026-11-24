local M = {}
local api = vim.api

function M.attach(picker, dirs)
  local buffer, window
  local function close()
    if window and api.nvim_win_is_valid(window) then api.nvim_win_close(window, true) end
    window, buffer = nil, nil
  end
  local get_options = picker.get_window_options
  picker.get_window_options = function(self, columns, lines)
    local height = math.min(#dirs, math.max(1, math.floor(lines / 4)))
    local reserved = lines >= 12 and height + 2 or 0
    local options = get_options(self, columns, lines - reserved)
    self.max_results = options.results.height
    if reserved == 0 then close(); return options end
    local top, left, right = math.huge, math.huge, 0
    for _, part in pairs(options) do
      top = math.min(top, part.line)
      left = math.min(left, part.col)
      right = math.max(right, part.col + part.width)
      part.line = part.line + reserved
    end
    local content = {}
    for index, path in ipairs(dirs) do
      if index > height then break end
      if index == height and #dirs > height then
        content[index] = '  +' .. (#dirs - height + 1) .. ' more folders (Ctrl+D to view all)'
      else
        content[index] = '  ' .. index .. '  ' .. vim.fn.fnamemodify(path, ':~'):gsub('\\', '/')
      end
    end
    local config = { relative = 'editor', style = 'minimal', focusable = false,
      row = math.max(0, top - 2), col = math.max(0, left - 2),
      width = math.max(1, math.min(columns - 2, right - left)), height = height,
      border = 'rounded', title = ' Search folders (' .. #dirs .. ') · Ctrl+D to edit ', title_pos = 'left', zindex = 50 }
    if not buffer or not api.nvim_buf_is_valid(buffer) then
      buffer = api.nvim_create_buf(false, true)
      vim.bo[buffer].bufhidden = 'wipe'
      vim.bo[buffer].filetype = 'movim_search_folders'
    end
    vim.bo[buffer].modifiable = true
    api.nvim_buf_set_lines(buffer, 0, -1, false, content)
    vim.bo[buffer].modifiable = false
    if window and api.nvim_win_is_valid(window) then api.nvim_win_set_config(window, config)
    else window = api.nvim_open_win(buffer, false, config) end
    vim.wo[window].winhighlight = 'Normal:TelescopeResultsNormal,FloatBorder:TelescopeResultsBorder,FloatTitle:TelescopeResultsTitle'
    vim.wo[window].wrap = false
    return options
  end
  api.nvim_create_autocmd('WinClosed', { pattern = tostring(picker.prompt_win), once = true, callback = close })
  picker:recalculate_layout()
end

return M
