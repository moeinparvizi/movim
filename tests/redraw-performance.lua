vim.opt.rtp:prepend(vim.fn.getcwd())
local display = require('utils.persian_display')
display.set_renderer('editor', false)
display.setup()
local original, redraws = vim.cmd, 0
vim.cmd = setmetatable({}, {
  __index = original,
  __call = function(_, command)
    if command == 'redraw!' then redraws = redraws + 1 else return original(command) end
  end,
})
vim.api.nvim_exec_autocmds('ModeChanged', { pattern = 'n:i' })
vim.api.nvim_exec_autocmds('ModeChanged', { pattern = 'i:n' })
assert(redraws == 0, 'Normal and Insert mode transitions should not force redraws')
vim.api.nvim_exec_autocmds('ModeChanged', { pattern = 'n:v' })
vim.api.nvim_exec_autocmds('ModeChanged', { pattern = 'v:n' })
assert(redraws == 2, 'Visual mode transitions still refresh Persian rendering')
vim.cmd = original
print('PASS unnecessary mode-change redraws eliminated')
vim.cmd('qa!')
