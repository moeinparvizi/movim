-- Built-in startup palette: no plugin manager, Git or network required.
vim.cmd('highlight clear')
vim.o.background = 'dark'
vim.o.termguicolors = true
vim.g.colors_name = 'movim'
local groups = {
  Normal = { fg = '#c0caf5', bg = '#1a1b26' },
  NormalNC = { fg = '#c0caf5', bg = '#1a1b26' },
  NormalFloat = { fg = '#c0caf5', bg = '#16161e' },
  FloatBorder = { fg = '#7aa2f7', bg = '#16161e' },
  EndOfBuffer = { fg = '#414868' },
  Comment = { fg = '#737da6', italic = true },
  String = { fg = '#9ece6a' },
  Number = { fg = '#ff9e64' },
  Constant = { fg = '#ff9e64' },
  Identifier = { fg = '#c0caf5' },
  Function = { fg = '#7aa2f7' },
  Statement = { fg = '#bb9af7' },
  Keyword = { fg = '#bb9af7' },
  Type = { fg = '#2ac3de' },
  Special = { fg = '#7dcfff' },
  PreProc = { fg = '#bb9af7' },
  Error = { fg = '#f7768e' },
  Visual = { bg = '#364a82' },
  Search = { fg = '#1a1b26', bg = '#e0af68' },
  CursorLine = { bg = '#292e42' },
  LineNr = { fg = '#737da6' },
  CursorLineNr = { fg = '#e0af68', bold = true },
  SignColumn = { bg = '#1a1b26' },
  StatusLine = { fg = '#c0caf5', bg = '#292e42' },
  StatusLineNC = { fg = '#737da6', bg = '#16161e' },
  Pmenu = { fg = '#c0caf5', bg = '#16161e' },
  PmenuSel = { fg = '#c0caf5', bg = '#364a82' },
}
for name, value in pairs(groups) do vim.api.nvim_set_hl(0, name, value) end
