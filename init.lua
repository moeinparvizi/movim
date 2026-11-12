-- movim — a Neovim-based IDE in the terminal
-- Repo: https://github.com/moeinparvizi/movim
-- Docs: docs/ (فارسی)

-- Comment.nvim integration does not need the legacy treesitter module.
vim.g.skip_ts_context_commentstring_module = true

-- Bootstrap everything
require("config.options")
require("config.lazy")
require("config.keymaps")
require("config.autocmds")
require("utils.bookmarks").setup()
require("utils.updates").setup()

-- Load persisted colorscheme (see lua/config/theme.lua + <leader>ut)
require("config.theme").load()

-- The bundled Persian keyboard starts in English; F9 toggles it in Insert mode.
