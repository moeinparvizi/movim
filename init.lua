-- movim — a Neovim-based IDE in the terminal
-- Repo: https://github.com/moeinparvizi/movim
-- Docs: docs/ and site/docs-en/README.md

-- Comment.nvim integration does not need the legacy treesitter module.
vim.g.skip_ts_context_commentstring_module = true

-- Resolve the configuration from this file, including installation paths with spaces.
vim.opt.runtimepath:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h"))

-- Bootstrap everything
require("config.options")
vim.cmd.colorscheme("movim")
require("config.lazy")
require("config.keymaps")
require("config.autocmds")
require("utils.bookmarks").setup()
require("utils.persian_display").setup()
require("utils.updates").setup()

-- Load persisted colorscheme (see lua/config/theme.lua + <leader>ut)
require("config.theme").load()

-- The bundled Persian keyboard starts in English; F9 toggles it in Insert mode.
