local api = vim.api
assert(vim.filetype.match({ filename = 'example.component.html' }) == 'htmlangular', 'Angular template filetype')
assert(vim.filetype.match({ filename = 'index.html' }) == 'html', 'regular HTML keeps its filetype')
local buf = api.nvim_create_buf(true, false)
api.nvim_set_current_buf(buf)
api.nvim_buf_set_lines(buf, 0, -1, false, {
  '@if (ready) {',
  '  <mat-form-field><input matInput [value]="name" (input)="save($event)"></mat-form-field>',
  '}',
})
vim.bo[buf].filetype = 'htmlangular'
local parser = vim.treesitter.get_parser(buf, 'angular')
assert(parser and parser:parse(), 'bundled Angular parser loads')
local tree = parser:parse()[1]:root()
assert(not tree:has_error(), 'Angular control flow and Material template parse cleanly: ' .. tree:sexpr())
local function has_capture(row, col, capture)
  for _, item in ipairs(vim.treesitter.get_captures_at_pos(buf, row, col)) do
    if item.capture == capture then return true end
  end
  return false
end
assert(has_capture(0, 1, 'keyword.conditional'), '@if keyword is highlighted')
assert(has_capture(1, 3, 'tag'), 'Material component tag is highlighted')
local call = assert(api.nvim_buf_get_lines(buf, 1, 2, false)[1]:find('save', 1, true)) - 1
assert(has_capture(1, call, 'function'), 'Angular expression call is highlighted')
for _, name in ipairs({ 'movim', 'tokyonight-night', 'catppuccin-macchiato', 'gruvbox', 'kanagawa', 'rose-pine', 'onedark', 'nightfox' }) do
  local ok = pcall(vim.cmd.colorscheme, name)
  assert(ok, 'Cannot load theme ' .. name)
  assert(has_capture(0, 1, 'keyword.conditional') and has_capture(1, 3, 'tag'), 'Angular captures missing in ' .. name)
end
local inline = api.nvim_create_buf(false, true)
api.nvim_set_current_buf(inline)
api.nvim_buf_set_lines(inline, 0, -1, false, { '@Component({ template: `@if (ready) { <mat-button>OK</mat-button> }` })', 'export class Demo {}' })
vim.bo[inline].filetype = 'typescript'
local ts = vim.treesitter.get_parser(inline, 'typescript')
ts:parse(true)
local angular_child = false
ts:for_each_tree(function(_, language_tree) if language_tree:lang() == 'angular' then angular_child = true end end)
assert(angular_child, 'Inline Angular component template is parsed as Angular')
print('PASS Angular control flow, Material tags, bindings and eight themes')
vim.cmd('qa!')
