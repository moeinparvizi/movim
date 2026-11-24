local M = {}

function M.setup()
  if M.installed then return end
  M.installed = true
  local function complete(callback)
    return function(...)
        local values = { n = select('#', ...), ... }
        vim.schedule(function()
          if callback then callback(unpack(values, 1, values.n)) end
          vim.schedule(function() vim.cmd('redraw!') end)
        end)
    end
  end
  local select_ui, input_ui = require('utils.select_popup').select, vim.ui.input
  vim.ui.select = function(items, options, callback)
    return select_ui(items, options, complete(callback))
  end
  vim.ui.input = function(options, callback)
    return input_ui(options, complete(callback))
  end
  local queued = false
  local group = vim.api.nvim_create_augroup('movim-panel-redraw', { clear = true })
  vim.api.nvim_create_autocmd('WinClosed', { group = group, callback = function(args)
    local win = tonumber(args.match)
    local ok, config = pcall(vim.api.nvim_win_get_config, win)
    if ok and config.relative ~= '' and not config.focusable then return end
    if queued then return end
    queued = true
    vim.schedule(function()
      queued = false
      vim.cmd('redraw!')
    end)
  end })
end

return M
