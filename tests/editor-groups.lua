vim.opt.rtp:prepend(vim.fn.getcwd())
vim.cmd('enew')
vim.bo.buftype = ''
require('utils.editor_groups').split(true)
local wins = vim.api.nvim_tabpage_list_wins(0)
assert(#wins == 2, 'vertical split must create two editor panes')
assert(math.abs(vim.api.nvim_win_get_width(wins[1]) - vim.api.nvim_win_get_width(wins[2])) <= 1)
assert(vim.wo[wins[1]].winbar ~= '' and vim.wo[wins[2]].winbar ~= '')
vim.ui.input = function(_, callback) callback('Backend') end
require('utils.named_tabs').create()
assert(vim.t.movim_name == 'Backend')
assert(require('utils.named_tabs').label():find('Backend', 1, true))
print('PASS equal editor splits and manually named workspace')
vim.cmd('qa!')
