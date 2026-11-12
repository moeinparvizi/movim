-- Small find/replace panel for the current buffer. Search text is literal.
local M = {}
local state

local function valid(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function start_typing(win)
  vim.defer_fn(function()
    if valid(win) and vim.api.nvim_get_current_win() == win and vim.api.nvim_get_mode().mode:sub(1, 1) ~= "i" then
      vim.api.nvim_feedkeys("i", "n", false)
    end
  end, 30)
end

local function pattern(text)
  return [[\V]] .. vim.fn.escape(text, [[\]])
end

local function contents(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return "" end
  return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
end

local function close()
  local s = state
  if not s then return end
  state = nil
  vim.cmd.stopinsert()
  for _, key in ipairs({ "button_win", "replace_win", "search_win" }) do
    local win = s[key]
    if valid(win) then pcall(vim.api.nvim_win_close, win, true) end
  end
  if valid(s.source_win) then vim.api.nvim_set_current_win(s.source_win) end
end

local function locate(s, flags)
  if state ~= s or not valid(s.source_win) or contents(s.search_buf) == "" then return end
  local expr = pattern(contents(s.search_buf))
  vim.fn.setreg("/", expr)
  vim.o.hlsearch = true
  vim.v.hlsearch = 1
  vim.api.nvim_win_call(s.source_win, function()
    vim.fn.search(expr, flags or "cw")
    vim.cmd("normal! zv")
  end)
end

local function position()
  local width = math.max(16, math.min(50, vim.o.columns - 6))
  return width, math.max(2, vim.o.columns - width - 2)
end

local function set_button(s)
  if not s.button_buf or not vim.api.nvim_buf_is_valid(s.button_buf) then return end
  vim.api.nvim_buf_set_lines(s.button_buf, 0, -1, false, { s.replace_open and "▾" or "▸" })
end

local function replace_one(s)
  local query = contents(s.search_buf)
  if query == "" or not valid(s.source_win) or not vim.bo[s.source_buf].modifiable then return end
  local expr = pattern(query)
  vim.api.nvim_win_call(s.source_win, function()
    local pos = vim.fn.searchpos(expr, "cW")
    if pos[1] == 0 then pos = vim.fn.searchpos(expr, "cw") end
    if pos[1] == 0 then return end
    local line = vim.api.nvim_buf_get_lines(s.source_buf, pos[1] - 1, pos[1], false)[1]
    local hit = vim.fn.matchstrpos(line, expr, pos[2] - 1)
    if hit[2] < 0 then return end
    vim.api.nvim_buf_set_text(s.source_buf, pos[1] - 1, hit[2], pos[1] - 1, hit[3], { contents(s.replace_buf) })
    vim.api.nvim_win_set_cursor(s.source_win, { pos[1], hit[2] })
  end)
  locate(s, "w")
end

local function replace_all(s)
  local query = contents(s.search_buf)
  if query == "" or not valid(s.source_win) or not vim.bo[s.source_buf].modifiable then return end
  local expr = pattern(query)
  local replacement = vim.fn.escape(contents(s.replace_buf), [[\&~]])
  local lines = vim.api.nvim_buf_get_lines(s.source_buf, 0, -1, false)
  local changed = false
  for i, line in ipairs(lines) do
    local replaced = vim.fn.substitute(line, expr, replacement, "g")
    if replaced ~= line then changed = true; lines[i] = replaced end
  end
  if changed then vim.api.nvim_buf_set_lines(s.source_buf, 0, -1, false, lines) end
  locate(s, "cw")
end

local function prompt(s, title, row)
  local width, col = position()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "findpanel"
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor", row = row, col = col, width = width, height = 1,
    style = "minimal", border = "rounded", title = title, title_pos = "left", zindex = 100,
  })
  vim.wo[win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder"
  return buf, win
end

local toggle_replace
local function bind(s, buf, is_replace)
  local function map(keys, fn, desc)
    vim.keymap.set({ "n", "i" }, keys, fn, { buffer = buf, silent = true, desc = desc })
  end
  map("<Esc>", close, "Close find")
  map("<C-c>", close, "Close find")
  map("<Tab>", function() toggle_replace(s) end, "Toggle or focus replace")
  map("<S-Tab>", function() if valid(s.search_win) then vim.api.nvim_set_current_win(s.search_win); vim.cmd.startinsert() end end, "Focus find")
  map("<Down>", function() locate(s, "w") end, "Next match")
  map("<Up>", function() locate(s, "bw") end, "Previous match")
  if is_replace then
    map("<CR>", function() replace_one(s) end, "Replace current match")
    map("<C-a>", function() replace_all(s) end, "Replace all matches")
  else
    map("<CR>", close, "Accept search")
  end
end

toggle_replace = function(s)
  if state ~= s then return end
  if not s.replace_open then
    s.replace_buf, s.replace_win = prompt(s, " Replace | Enter: one | Ctrl+A: all ", 3)
    s.replace_open = true
    bind(s, s.replace_buf, true)
    if s.saved_replace then vim.api.nvim_buf_set_lines(s.replace_buf, 0, -1, false, { s.saved_replace }) end
    set_button(s)
    vim.api.nvim_set_current_win(s.replace_win)
  elseif vim.api.nvim_get_current_win() == s.replace_win then
    vim.api.nvim_set_current_win(s.search_win)
  else
    vim.api.nvim_set_current_win(s.replace_win)
  end
  start_typing(vim.api.nvim_get_current_win())
end

local function toggle_button(s)
  if state ~= s then return end
  if s.replace_open then
    s.saved_replace = contents(s.replace_buf)
    if valid(s.replace_win) then vim.api.nvim_win_close(s.replace_win, true) end
    s.replace_open = false
    s.replace_win, s.replace_buf = nil, nil
    set_button(s)
    if valid(s.search_win) then vim.api.nvim_set_current_win(s.search_win); start_typing(s.search_win) end
  else
    toggle_replace(s)
  end
end

function M.open()
  if state then close() end
  local s = { source_win = vim.api.nvim_get_current_win(), source_buf = vim.api.nvim_get_current_buf() }
  if vim.bo[s.source_buf].buftype ~= "" then return end
  state = s
  s.search_buf, s.search_win = prompt(s, " Find | Tab: replace | ↑↓: next ", 0)
  bind(s, s.search_buf, false)
  local _, col = position()
  s.button_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[s.button_buf].bufhidden = "wipe"
  s.button_win = vim.api.nvim_open_win(s.button_buf, false, {
    relative = "editor", row = 1, col = col - 2, width = 1, height = 1,
    style = "minimal", border = "none", zindex = 110,
  })
  set_button(s)
  vim.keymap.set("n", "<LeftMouse>", function() toggle_button(s) end, { buffer = s.button_buf, silent = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    buffer = s.button_buf, callback = function() vim.schedule(function() toggle_button(s) end) end,
  })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = s.search_buf, callback = function() locate(s, "cw") end,
  })
  vim.api.nvim_create_autocmd("VimResized", {
    buffer = s.search_buf,
    callback = function()
      local width, x = position()
      if valid(s.search_win) then vim.api.nvim_win_set_config(s.search_win, { relative = "editor", width = width, row = 0, col = x }) end
      if valid(s.replace_win) then vim.api.nvim_win_set_config(s.replace_win, { relative = "editor", width = width, row = 3, col = x }) end
      if valid(s.button_win) then vim.api.nvim_win_set_config(s.button_win, { relative = "editor", row = 1, col = x - 2 }) end
    end,
  })
  vim.api.nvim_set_current_win(s.search_win)
  vim.cmd.startinsert()
end

return M
