-- Neovim requires the active window cursor to remain visible. Scroll a passive
-- view of the same buffer instead, leaving the editing window and marks intact.
local M = {}
local api = vim.api
local view
local internal = false
local namespace = api.nvim_create_namespace('movim-mouse-scroll')
local function valid(win) return win and api.nvim_win_is_valid(win) end
local function in_window(win, fn)
  local ignored = vim.o.eventignore
  vim.o.eventignore = 'all'
  internal = true
  local ok, result = pcall(api.nvim_win_call, win, fn)
  internal = false
  vim.o.eventignore = ignored
  if not ok then error(result) end
  return result
end

function M.close(click)
  local saved = view
  if not saved then return end
  view = nil
  if click and valid(saved.win) and valid(saved.source) then
    local mouse = vim.fn.getmousepos()
    if mouse.winid == saved.win and mouse.line > 0 then
      local scrolled = in_window(saved.win, vim.fn.winsaveview)
      scrolled.lnum, scrolled.col = mouse.line, math.max(0, mouse.column - 1)
      in_window(saved.source, function() vim.fn.winrestview(scrolled) end)
    end
  end
  if valid(saved.win) then api.nvim_win_close(saved.win, true) end
  if saved.cursor then vim.o.guicursor = saved.cursor end
end

local function create(source)
  local position = vim.fn.win_screenpos(source)
  local winbar = vim.fn.getwininfo(source)[1].winbar or 0
  local buf = api.nvim_win_get_buf(source)
  local original = in_window(source, vim.fn.winsaveview)
  local win = api.nvim_open_win(buf, false, { relative = 'editor', row = position[1] - 1 + winbar,
    col = position[2] - 1, width = api.nvim_win_get_width(source), height = api.nvim_win_get_height(source),
    focusable = false, mouse = true, border = 'none', zindex = 40, noautocmd = true })
  for _, name in ipairs({ 'number', 'numberwidth', 'signcolumn', 'foldcolumn', 'foldenable', 'foldmethod',
    'foldexpr', 'foldtext', 'foldlevel', 'wrap', 'linebreak', 'breakindent', 'showbreak', 'list', 'listchars',
    'conceallevel', 'concealcursor', 'tabstop', 'winhighlight', 'statuscolumn' }) do
    pcall(function() vim.wo[win][name] = vim.wo[source][name] end)
  end
  vim.wo[win].winhighlight = 'NormalFloat:Normal,FloatBorder:Normal'
  vim.wo[win].winbar = ''
  vim.wo[win].relativenumber, vim.wo[win].cursorline, vim.wo[win].cursorcolumn = false, false, false
  vim.wo[win].scrolloff, vim.wo[win].sidescrolloff = 0, 0
  in_window(win, function() vim.fn.winrestview(original) end)
  view = { source = source, win = win, buf = buf, position = api.nvim_win_get_cursor(source) }
  -- Do not paint a cursor over unrelated text while its editing window is covered.
  if source == api.nvim_get_current_win() then
    view.cursor = vim.o.guicursor
    api.nvim_set_hl(0, 'MovimScrollCursor', { blend = 100, reverse = false })
    vim.o.guicursor = 'a:MovimScrollCursor/MovimScrollCursor-blinkon0'
  end
  return view
end

function M.scroll(key)
  local mouse = vim.fn.getmousepos()
  local target = mouse.winid
  if view and target == view.win then target = view.source end
  if not valid(target) then return end
  local buf = api.nvim_win_get_buf(target)
  if vim.bo[buf].buftype ~= '' or api.nvim_win_get_config(target).relative ~= '' then
    M.close()
    api.nvim_feedkeys(vim.keycode(key), 'n', false)
    return
  end
  if view and view.source ~= target then M.close() end
  local current = view or create(target)
  local vertical = key == '<ScrollWheelDown>' or key == '<ScrollWheelUp>'
  local direction = (key == '<ScrollWheelDown>' or key == '<ScrollWheelRight>') and 1 or -1
  local amount = tonumber(vim.o.mousescroll:match((vertical and 'ver:' or 'hor:') .. '(%d+)')) or (vertical and 3 or 6)
  if amount == 0 then M.close(); return end
  in_window(current.win, function()
    if vertical then
      vim.cmd('normal! ' .. amount .. (direction == 1 and '\005' or '\025'))
    else
      vim.cmd('normal! ' .. amount .. (direction == 1 and 'zl' or 'zh'))
    end
  end)
end

function M.setup()
  api.nvim_set_decoration_provider(namespace, { on_win = function(_, win, buf)
    if not view or win ~= view.win or api.nvim_get_current_win() ~= view.source then return false end
    local row, col = view.position[1] - 1, view.position[2]
    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ''
    local char = vim.fn.strcharpart(line:sub(col + 1), 0, 1)
    api.nvim_buf_set_extmark(buf, namespace, row, col, { ephemeral = true,
      virt_text = { { char ~= '' and char or ' ', 'Cursor' } }, virt_text_pos = 'overlay', priority = 250 })
    return false
  end })
  for _, key in ipairs({ '<ScrollWheelDown>', '<ScrollWheelUp>', '<ScrollWheelLeft>', '<ScrollWheelRight>' }) do
    vim.keymap.set({ 'n', 'i', 'x' }, key, function() M.scroll(key) end, { silent = true, desc = 'Scroll without moving edit cursor' })
  end
  vim.on_key(function(key, typed)
    if not view or internal then return end
    local name = vim.fn.keytrans((typed ~= '' and typed) or key)
    if name:find('ScrollWheel', 1, true) or name:find('MouseMove', 1, true) or name == '<Cmd>' then return end
    -- The multicursor mapping reads the passive view's mouse coordinates while
    -- keeping the real editing cursor where it was.
    if name:find('C%-LeftMouse') or name:find('C%-LeftRelease') then return end
    M.close(name:find('Mouse', 1, true) ~= nil)
  end, namespace)
  api.nvim_create_autocmd({ 'WinLeave', 'BufLeave', 'VimResized', 'WinResized', 'TabLeave', 'TextChanged', 'TextChangedI' }, {
    group = api.nvim_create_augroup('movim-mouse-scroll', { clear = true }), callback = function() M.close() end,
  })
  api.nvim_create_autocmd('WinClosed', { group = 'movim-mouse-scroll', callback = function(event)
    if view and (tonumber(event.match) == view.source or tonumber(event.match) == view.win) then M.close() end
  end })
end

return M
