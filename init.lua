-- movim — a Neovim-based IDE in the terminal
-- Repo: https://github.com/moeinparvizi/movim
-- Docs: docs/ and site/docs-en/README.md

-- Comment.nvim integration does not need the legacy treesitter module.
vim.g.skip_ts_context_commentstring_module = true

-- Resolve the configuration from this file, including installation paths with spaces.
vim.opt.runtimepath:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h"))
local config_root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h')
if require('utils.updates').bootstrap(config_root) then
  -- This chunk was read before the transaction. Execute the updated entrypoint
  -- and updater so new startup features are available on this very launch.
  package.loaded['utils.updates'] = nil
  dofile(config_root .. '/init.lua')
  return
end

-- Bootstrap everything
require("config.options")
require("utils.angular").setup()
vim.cmd.colorscheme("movim")
require("config.lazy")
require("config.keymaps")
require("config.autocmds")
require("utils.hover_word").setup()
require("utils.mouse_hover").setup()
require("utils.ui_close").setup()
require("utils.workspace").setup()
require("utils.editor_groups").setup()
require("utils.named_tabs").setup()
require("utils.bookmarks").setup()
require("utils.persian_display").setup()
require("utils.updates").setup()

-- The standard distribution includes the AI panel.
local ai_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/ai"
if vim.fn.filereadable(ai_root .. "/lua/movim_ai/init.lua") == 1 then
  vim.opt.runtimepath:prepend(ai_root)
  require("movim_ai").setup()
end

-- Load persisted colorscheme (see lua/config/theme.lua + <leader>ut)
require("config.theme").load()

-- Personal settings are deliberately outside the distribution manifest.
local user_config = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h') .. '/user.lua'
if vim.fn.filereadable(user_config) == 1 then
  local ok, err = pcall(dofile, user_config)
  if not ok then vim.notify('user.lua: ' .. tostring(err), vim.log.levels.ERROR) end
end

-- The bundled Persian keyboard starts in English; F9 toggles it in Insert mode.
