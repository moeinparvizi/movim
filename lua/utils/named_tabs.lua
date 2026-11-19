local M = {}

local function name_tab(tab, prompt)
  vim.ui.input({ prompt = prompt, default = vim.t[tab].movim_name or '' }, function(name)
    if not name or vim.trim(name) == '' or not vim.api.nvim_tabpage_is_valid(tab) then return end
    vim.t[tab].movim_name = vim.trim(name)
    require('utils.workspace').queue()
    vim.cmd('redrawtabline')
  end)
end

function M.create()
  vim.ui.input({ prompt = 'New workspace name: ' }, function(name)
    if not name or vim.trim(name) == '' then return end
    vim.cmd('tab split')
    vim.t.movim_name = vim.trim(name)
    require('utils.workspace').queue()
    vim.cmd('redrawtabline')
  end)
end

function M.rename()
  name_tab(vim.api.nvim_get_current_tabpage(), 'Workspace name: ')
end

function M.select()
  local tabs = vim.api.nvim_list_tabpages()
  vim.ui.select(tabs, { prompt = 'Workspace', format_item = function(tab)
    return vim.t[tab].movim_name or 'Main'
  end }, function(tab)
    if tab and vim.api.nvim_tabpage_is_valid(tab) then vim.api.nvim_set_current_tabpage(tab) end
  end)
end

function M.label()
  local labels = {}
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local name = vim.t[tab].movim_name
    if name then
      name = name:gsub('%%', '%%%%')
      labels[#labels + 1] = (tab == vim.api.nvim_get_current_tabpage() and '[' .. name .. ']' or name)
    end
  end
  return #labels > 0 and ('  ' .. table.concat(labels, '  ') .. '  ') or ''
end

function M.setup()
  vim.keymap.set('n', '<leader>qn', M.create, { desc = 'Create named workspace' })
  vim.keymap.set('n', '<leader>qr', M.rename, { desc = 'Rename workspace' })
  vim.keymap.set('n', '<leader>qt', M.select, { desc = 'Switch named workspace' })
end

return M
