-- General Neovim options (behavior shared with every plugin)
local opt = vim.opt

-- Leader keys (must be set before lazy.nvim boots)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- UI
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.termguicolors = true
opt.showmode = false -- lualine/bufferline already show it
opt.showtabline = 2 -- Keep the buffer tabs visible, including for a single file.
opt.pumheight = 14
opt.laststatus = 3 -- one global statusline
opt.cmdheight = 1
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.wrap = false
opt.linebreak = true -- when wrap is on, break at spaces (good for Persian prose)
opt.breakindent = true

-- Editing
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true
opt.autoindent = true
opt.updatetime = 250
opt.timeoutlen = 3000
opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "split" -- live :s preview
opt.splitbelow = true
opt.splitright = true
opt.autoread = true
opt.mouse = "a" -- enables Ctrl+Click / Alt+Click features
opt.clipboard = "unnamedplus" -- system clipboard like WebStorm

-- Persistent undo (per-file undo history across restarts)
opt.undofile = true
local undo_dir = vim.fs.joinpath(vim.fn.stdpath("state"), "undo"):gsub("\\", "/")
vim.fn.mkdir(undo_dir, "p")
opt.undodir = { undo_dir }

-- Sessions / swap
opt.swapfile = false
opt.writebackup = false

-- Folding (nvim-ufo enhances these)
opt.foldcolumn = "1"
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.foldenable = true

-- The editor shapes Arabic-script text; the terminal still provides glyphs.
opt.arabicshape = true
opt.delcombine = true
-- Load the bundled Persian layout while leaving English input as the default.
opt.keymap = "persian"
opt.iminsert = 0
opt.imsearch = -1

-- Search
opt.hlsearch = true

-- Don't continue comments with o/O automatically
opt.formatoptions:remove({ "o" })

-- netrw is replaced by neo-tree
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrw = 1
