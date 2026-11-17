-- Persistent terminal sessions shared by independently selectable panel splits.
local M = {}
local panel = { sessions = {}, active = nil, win = nil, wins = {}, next_id = 1 }
local function project()
  return require('utils.workspace').root or vim.fn.getcwd()
end
local function project_sessions()
  return vim.tbl_filter(function(item) return item.project == project() end, panel.sessions)
end

local function valid(win)
  return win and vim.api.nvim_win_is_valid(win) and panel.wins[win]
end

local function find(id)
  for index, item in ipairs(panel.sessions) do
    if item.id == id then return item, index end
  end
end

local function item_in(win)
  if not valid(win) then return end
  local buf = vim.api.nvim_win_get_buf(win)
  for _, item in ipairs(panel.sessions) do
    if item.buf == buf then return item end
  end
end

local function current_win()
  local win = vim.api.nvim_get_current_win()
  if valid(win) then return win end
  if valid(panel.win) then return panel.win end
  for candidate in pairs(panel.wins) do
    if valid(candidate) then return candidate end
    panel.wins[candidate] = nil
  end
end

local function redraw()
  for win in pairs(panel.wins) do
    if valid(win) then
      local current = item_in(win)
      local parts = { "%#TabLine# Term %1@v:lua.NemovimTerminalAction@+%T "
        .. "%2@v:lua.NemovimTerminalAction@rename%T "
        .. "%4@v:lua.NemovimTerminalAction@split%T "
        .. "%3@v:lua.NemovimTerminalAction@hide%T  " }
      for _, item in ipairs(project_sessions()) do
        local hl = current == item and "%#TabLineSel#" or "%#TabLine#"
        local label = vim.fn.strcharpart(item.name, 0, 12)
        if vim.fn.strchars(item.name) > 12 then label = label .. "…" end
        label = label:gsub("%%", "%%%%")
        parts[#parts + 1] = hl .. "%" .. item.id .. "@v:lua.NemovimTerminalClick@ "
          .. label .. (item.exited and " (exited)" or "") .. " %T"
          .. "%" .. item.id .. "@v:lua.NemovimTerminalClose@x%T "
      end
      vim.wo[win].winbar = table.concat(parts)
    else
      panel.wins[win] = nil
    end
  end
  vim.cmd("redrawstatus")
end

local function show(item, win)
  if not item or not valid(win) or not vim.api.nvim_buf_is_valid(item.buf) then return end
  panel.win, panel.active = win, item.id
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_buf(win, item.buf)
  redraw()
  if not item.exited then vim.cmd("startinsert") end
end

local function bind(buf)
  local opts = { buffer = buf, silent = true }
  for _, mode in ipairs({ "n", "t" }) do
    vim.keymap.set(mode, "<M-]>", function() M.cycle(1) end, vim.tbl_extend("force", opts, { desc = "Next terminal tab" }))
    vim.keymap.set(mode, "<M-[>", function() M.cycle(-1) end, vim.tbl_extend("force", opts, { desc = "Previous terminal tab" }))
    vim.keymap.set(mode, "<M-n>", function() M.new() end, vim.tbl_extend("force", opts, { desc = "New terminal tab" }))
  end
end

local function register(win)
  panel.wins[win], panel.win = true, win
  vim.wo[win].winfixheight = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
end

local function ensure_window()
  local win = current_win()
  if win then vim.api.nvim_set_current_win(win); panel.win = win; return win end
  local height = require('utils.workspace').preference('terminal_height', 15)
  height = math.max(3, math.min(height, math.floor(vim.o.lines * 0.7)))
  -- Split the current buffer; :new would leave an extra listed [No Name].
  vim.cmd('botright ' .. height .. 'split')
  win = vim.api.nvim_get_current_win()
  register(win)
  return win
end

function M.new()
  local win = ensure_window()
  local buf = vim.api.nvim_create_buf(false, false)
  vim.bo[buf].bufhidden = "hide"
  vim.b[buf].movim_terminal_panel = true
  local used = {}
  for _, session in ipairs(project_sessions()) do used[session.name] = true end
  local number = 1
  while used[tostring(number)] do number = number + 1 end
  local item = { id = panel.next_id, buf = buf, name = tostring(number), project = project() }
  panel.next_id = panel.next_id + 1
  panel.sessions[#panel.sessions + 1] = item
  panel.active = item.id
  vim.api.nvim_win_set_buf(win, buf)
  local ok, job = pcall(vim.fn.termopen, vim.o.shell, {
    cwd = vim.fn.getcwd(),
    on_exit = function(_, code)
      vim.schedule(function()
        item.exited, item.code = true, code
        redraw()
      end)
    end,
  })
  if not ok or type(job) ~= "number" or job <= 0 then
    table.remove(panel.sessions, #panel.sessions)
    local items = project_sessions()
    local previous = items[#items]
    panel.active = previous and previous.id or nil
    if previous then show(previous, win) else M.hide() end
    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    return vim.notify("Could not start terminal: " .. tostring(job), vim.log.levels.ERROR)
  end
  item.job = job
  vim.bo[buf].buflisted = false
  bind(buf)
  redraw()
  vim.cmd("startinsert")
end

function M.hide()
  local win = current_win()
  if win then require('utils.workspace').preference('terminal_height', 15, vim.api.nvim_win_get_height(win)) end
  local item = item_in(win)
  if item then panel.active = item.id end
  local windows = {}
  for candidate in pairs(panel.wins) do if valid(candidate) then windows[#windows + 1] = candidate end end
  for _, candidate in ipairs(windows) do
    if vim.api.nvim_win_is_valid(candidate) then
      panel.wins[candidate] = nil
      if #vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(candidate)) == 1 then
        vim.api.nvim_win_set_buf(candidate, vim.api.nvim_create_buf(true, false))
        vim.wo[candidate].winbar = ""
        vim.wo[candidate].winfixheight = false
        vim.api.nvim_win_call(candidate, function() require('utils.buf').dashboard() end)
      else
        vim.api.nvim_win_close(candidate, true)
      end
    end
  end
  panel.win = nil
end

function M.toggle()
  if current_win() then return M.hide() end
  local win = ensure_window()
  local item = find(panel.active)
  if not item or item.project ~= project() then
    local items = project_sessions(); item = items[#items]
  end
  if item and vim.api.nvim_buf_is_valid(item.buf) then show(item, win) else M.new() end
end

function M.select(id, win)
  local item = find(id)
  if not item then return end
  show(item, valid(win) and win or ensure_window())
end

function M.cycle(step)
  local win = current_win()
  local current = item_in(win) or find(panel.active)
  local items, index = project_sessions(), nil
  for i, item in ipairs(items) do if current and current.id == item.id then index = i; break end end
  if not index then return end
  M.select(items[((index - 1 + step) % #items) + 1].id, win)
end

function M.split()
  local win = ensure_window()
  vim.api.nvim_set_current_win(win)
  vim.cmd("belowright vsplit")
  register(vim.api.nvim_get_current_win())
  M.new()
end

function M.rename(id)
  local win = current_win()
  local item = find(id) or item_in(win)
  if not item then return end
  -- UI prompts need Normal mode when invoked from an active terminal.
  vim.cmd("stopinsert")
  vim.schedule(function()
    vim.ui.input({ prompt = "Terminal name: ", default = item.name }, function(value)
      if not value or not find(item.id) then return end
      value = vim.trim(value:gsub("[%c]", " "))
      if value == "" then return end
      item.name = vim.fn.strcharpart(value, 0, 40)
      redraw()
    end)
  end)
end

function M.close(id)
  local win = current_win()
  local item
  if id then item = find(id) else item = item_in(win) or find(panel.active) end
  if not item then return end
  local _, index = find(item.id)
  table.remove(panel.sessions, index)
  local items = project_sessions()
  local next_item = items[math.min(index, #items)]
  if panel.active == item.id then panel.active = next_item and next_item.id or nil end
  if not next_item then
    M.hide()
  else
    local showing = {}
    for candidate in pairs(panel.wins) do
      if valid(candidate) and vim.api.nvim_win_get_buf(candidate) == item.buf then showing[#showing + 1] = candidate end
    end
    for _, candidate in ipairs(showing) do
      local alternative
      for _, session in ipairs(items) do
        local used = false
        for other in pairs(panel.wins) do
          if other ~= candidate and valid(other) and vim.api.nvim_win_get_buf(other) == session.buf then used = true end
        end
        if not used then alternative = session; break end
      end
      if alternative then
        vim.api.nvim_win_set_buf(candidate, alternative.buf)
      else
        local count = 0
        for other in pairs(panel.wins) do if valid(other) then count = count + 1 end end
        if count > 1 then
          panel.wins[candidate] = nil
          vim.api.nvim_win_close(candidate, true)
        else
          vim.api.nvim_win_set_buf(candidate, next_item.buf)
        end
      end
    end
  end
  if vim.api.nvim_buf_is_valid(item.buf) then vim.api.nvim_buf_delete(item.buf, { force = true }) end
  redraw()
end

local function mouse_win()
  local win = vim.fn.getmousepos().winid
  return valid(win) and win or current_win()
end

_G.NemovimTerminalClick = function(id) M.select(id, mouse_win()) end
_G.NemovimTerminalClose = function(id) M.close(id) end
_G.NemovimTerminalAction = function(id)
  local win = mouse_win()
  if win then vim.api.nvim_set_current_win(win); panel.win = win end
  if id == 1 then M.new() elseif id == 2 then M.rename() elseif id == 3 then M.hide() elseif id == 4 then M.split() end
end

return M
