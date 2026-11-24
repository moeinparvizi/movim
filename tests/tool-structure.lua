local root = vim.env.MOVIM_TOOLS_TEST_DIR:gsub('\\', '/')
vim.o.columns, vim.o.lines = 140, 40
vim.fn.writefile({ 'export function example(value) {', '  return value;', '}', 'class Service { run() {} }' }, root .. '/outline.js')
vim.cmd('edit ' .. vim.fn.fnameescape(root .. '/outline.js'))
local source = vim.api.nvim_get_current_buf()
require('lazy').load({ plugins = { 'aerial.nvim' } })
require('aerial').open({ focus = false })
local received = vim.wait(5000, function() return require('aerial.data').has_received_data(source) end)
assert(received, 'Structure stays loading instead of showing JavaScript symbols: ' .. vim.api.nvim_exec2('messages', { output = true }).output)
local names = {}
for _, symbol in ipairs(require('aerial.data').get_or_create(source).items) do names[#names + 1] = symbol.name end
assert(vim.tbl_contains(names, 'example'), 'Function missing from Structure: ' .. vim.inspect(names))
print('PASS structure complete')
vim.cmd('qa!')
