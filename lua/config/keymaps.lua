-- Global keymaps (plugin-specific keymaps live in each plugin spec)
local map = function(lhs, rhs, desc, mode)
  vim.keymap.set(mode or "n", lhs, rhs, { desc = desc, silent = true })
end

-----------------------------------------------------------
-- Persian input: F9 toggles the Persian keyboard inside insert mode
-----------------------------------------------------------
map("<F9>", "<C-^>", "Toggle Persian/English typing (insert)", { "i", "c" })
map("<M-Space>", "‌", "Insert zero-width non-joiner (ZWNJ)", "i")
map("<leader>ur", function()
  vim.wo.rightleft = not vim.wo.rightleft
  vim.notify("Text direction: " .. (vim.wo.rightleft and "right to left" or "left to right"))
end, "Toggle right-to-left display")

map("<leader>uP", "<cmd>PersianDisplayToggle<CR>", "Toggle Persian display correction")

-----------------------------------------------------------
-- Better defaults
-----------------------------------------------------------
map("<Esc>", "<cmd>nohlsearch<CR>", "Clear search highlight")
map("j", "gj", "Move down by display line")
map("k", "gk", "Move up by display line")
map("<C-d>", "<C-d>zz", "Half page down")
map("<C-u>", "<C-u>zz", "Half page up")
map("n", "nzzzv", "Next search result")
map("N", "Nzzzv", "Previous search result")
map("/", function() require("utils.find_panel").open() end, "Find and replace in current file")
map("Q", "<nop>", "Disable Ex mode")
-- Move selected lines up/down (like WebStorm Shift+Cmd+Up/Down)
map("J", ":m '>+1<CR>gv=gv", "Move selection down", "v")
map("K", ":m '<-2<CR>gv=gv", "Move selection up", "v")
-- Keep the yanked word when pasting over a selection
map("p", '"_dp', "Paste without yanking selection", "x")
map("P", '"_dP', "Paste (before) without yanking", "x")

-----------------------------------------------------------
-- Window management  (docs/03-windows-buffers-tabs.md)
-----------------------------------------------------------
map("<C-h>", "<C-w>h", "Go to left window")
map("<C-j>", "<C-w>j", "Go to below window")
map("<C-k>", "<C-w>k", "Go to above window")
map("<C-l>", "<C-w>l", "Go to right window")
map("<C-Up>", "<cmd>resize +2<CR>", "Increase window height")
map("<C-Down>", "<cmd>resize -2<CR>", "Decrease window height")
map("<C-Left>", "<cmd>vertical resize -2<CR>", "Decrease window width")
map("<C-Right>", "<cmd>vertical resize +2<CR>", "Increase window width")
map("<leader>wv", "<C-w>v", "Split window vertically")
map("<leader>ws", "<C-w>s", "Split window horizontally")
map("<leader>wq", "<C-w>c", "Close window")
map("<leader>wo", "<C-w>o", "Close other windows")
map("<leader>wh", "<C-w>H", "Move window to far left")
map("<leader>wj", "<C-w>J", "Move window to far bottom")
map("<leader>wk", "<C-w>K", "Move window to far top")
map("<leader>wl", "<C-w>L", "Move window to far right")
map("<leader>w=", "<C-w>=", "Equalize window sizes")
map("<leader>ww", "<C-w>w", "Cycle windows")

-- Terminal-mode navigation
map("<C-h>", "<C-\\><C-n><C-w>h", "Terminal: go left", "t")
map("<C-j>", "<C-\\><C-n><C-w>j", "Terminal: go down", "t")
map("<C-k>", "<C-\\><C-n><C-w>k", "Terminal: go up", "t")
map("<C-l>", "<C-\\><C-n><C-w>l", "Terminal: go right", "t")

-----------------------------------------------------------
-- Buffers / tabs (bufferline covers the tab bar)
-----------------------------------------------------------
map("<S-h>", "<cmd>bprevious<CR>", "Previous buffer")
map("<S-l>", "<cmd>bnext<CR>", "Next buffer")
map("<leader>bd", function()
  require("utils.buf").delete_safe()
end, "Delete buffer")
map("<leader>bo", "<cmd>%bd|e#|bd#<CR>", "Close other buffers")
for i = 1, 9 do
  map("<leader>" .. i, ":" .. i .. "b<CR>", "Go to buffer " .. i)
end

-----------------------------------------------------------
-- Alt+Click → open the definition in a new tab
-- Ctrl+Click → add another cursor (multiple-cursors.nvim)
-----------------------------------------------------------
vim.keymap.set("n", "<M-LeftMouse>", function()
  local pos = vim.fn.getmousepos()
  if pos and pos.winid == vim.api.nvim_get_current_win() then
    vim.api.nvim_win_set_cursor(0, { pos.line, math.max(pos.column - 1, 0) })
    local source_win = vim.api.nvim_get_current_win()
    vim.lsp.buf.definition({
      on_list = function(result)
        local function open_definition(item)
          if not item or not vim.api.nvim_win_is_valid(source_win) then return end
          local bufnr = item.bufnr
          if not bufnr or bufnr == 0 then
            if not item.filename or item.filename == "" then return end
            bufnr = vim.fn.bufadd(item.filename)
          end
          vim.api.nvim_set_current_win(source_win)
          vim.cmd("normal! m'")
          vim.cmd("tab split")
          vim.bo[bufnr].buflisted = true
          vim.api.nvim_win_set_buf(0, bufnr)
          vim.api.nvim_win_set_cursor(0, { item.lnum, math.max((item.col or 1) - 1, 0) })
          vim.cmd("normal! zv")
        end
        if #result.items == 1 then
          open_definition(result.items[1])
        else
          vim.ui.select(result.items, {
            prompt = "Choose a definition",
            format_item = function(item)
              local name = item.filename or vim.api.nvim_buf_get_name(item.bufnr)
              return (name ~= "" and name or "[No Name]") .. ":" .. item.lnum
            end,
          }, open_definition)
        end
      end,
    })
  end
end, { desc = "Alt+Click: open definition in a new tab" })

vim.keymap.set("n", "<M-LeftRelease>", "<LeftRelease>", { desc = "Alt release" })

-----------------------------------------------------------
-- Quickfix / location lists
-----------------------------------------------------------
map("[q", "<cmd>cprev<CR>", "Previous quickfix item")
map("]q", "<cmd>cnext<CR>", "Next quickfix item")

-----------------------------------------------------------
-- Toggle group: <leader>u
-----------------------------------------------------------
map("<leader>uw", function()
  vim.opt.wrap = not vim.opt.wrap:get()
end, "Toggle line wrap")
map("<leader>us", function()
  vim.opt.spell = not vim.opt.spell:get()
end, "Toggle spell check")
map("<leader>ul", function()
  vim.opt.relativenumber = not vim.opt.relativenumber:get()
end, "Toggle relative numbers")
map("<leader>uL", function()
  vim.opt.number = not vim.opt.number:get()
end, "Toggle line numbers")

-- WebStorm Windows/Linux profile. Terminal support for modified keys varies.
-- Set vim.g.webstorm_keymaps = false before loading this module to opt out.
if vim.g.webstorm_keymaps ~= false then
  local actions = {
    { "<C-b>", function() vim.lsp.buf.definition() end, "Go to declaration" },
    { "<C-M-b>", function() vim.lsp.buf.implementation() end, "Go to implementation" },
    { "<C-S-b>", function() vim.lsp.buf.type_definition() end, "Go to type definition" },
    { "<M-F7>", function() vim.lsp.buf.references() end, "Find usages" },
    { "<C-F12>", "<cmd>Telescope lsp_document_symbols<CR>", "File structure" },
    { "<F8>", function() require("dap").step_over() end, "Debug step over" },
    { "<F7>", function() require("dap").step_into() end, "Debug step into" },
    { "<C-F8>", function() require("dap").toggle_breakpoint() end, "Toggle breakpoint" },
    { "<S-F8>", function() require("dap").step_out() end, "Debug step out" },
    { "<C-S-n>", "<cmd>Telescope find_files<CR>", "Find file" },
    { "<C-p>", function() vim.lsp.buf.signature_help() end, "Parameter information" },
    { "<C-q>", function() vim.lsp.buf.hover() end, "Quick documentation" },
    { "<C-e>", "<cmd>Telescope oldfiles<CR>", "Recent files" },
    { "<C-S-f>", "<cmd>Telescope live_grep<CR>", "Find in project" },
    { "<C-S-a>", "<cmd>Telescope commands<CR>", "Find action" },
    { "<S-F2>", function() vim.diagnostic.jump({ count = -1, float = true }) end, "Previous diagnostic" },
    { "<M-CR>", function() vim.lsp.buf.code_action() end, "Code actions" },
  }
  map("<F9>", function() require("dap").continue() end, "Debug resume")
  for _, a in ipairs(actions) do
    vim.keymap.set("n", a[1], a[2], { desc = a[3], silent = true })
    vim.keymap.set("i", a[1], function()
      vim.cmd.stopinsert()
      vim.schedule(function()
        if type(a[2]) == "function" then a[2]() else vim.cmd(a[2]:gsub("<cmd>", ""):gsub("<CR>", "")) end
      end)
    end, { desc = a[3], silent = true })
  end
end

-- Some terminals report Shift+F6 as F18. F2 and Space c r are accessible
-- alternatives when the terminal or operating system intercepts Shift+F6.
local rename_symbol = function() require("utils.rename").symbol() end
for _, key in ipairs({ "<S-F6>", "<F18>", "<F2>" }) do
  vim.keymap.set("n", key, rename_symbol, { desc = "Rename symbol", silent = true })
  vim.keymap.set("i", key, function()
    vim.cmd.stopinsert()
    vim.schedule(rename_symbol)
  end, { desc = "Rename symbol", silent = true })
end
map("<leader>cr", rename_symbol, "Rename symbol")
vim.api.nvim_create_user_command("RenameSymbol", rename_symbol, { desc = "Rename symbol using the language server" })
map("<leader>uf", function()
  vim.g.disable_autoformat = not vim.g.disable_autoformat
  vim.notify("Format on save: " .. (vim.g.disable_autoformat and "off" or "on"))
end, "Toggle format on save")
map("<leader>so", function()
  vim.lsp.buf.code_action({ context = { only = { "source.organizeImports" } }, apply = true })
end, "Organize imports")
