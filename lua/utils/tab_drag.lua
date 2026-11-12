-- Drag a bufferline entry into an editor window to split it at an edge.
local M = {}
local drag

local function valid(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function close_preview(s)
  if valid(s.preview_win) then pcall(vim.api.nvim_win_close, s.preview_win, true) end
  s.preview_win, s.preview_buf, s.preview_key = nil, nil, nil
end

local function target_at(pos)
  local win = pos.winid
  if not valid(win) or pos.winrow < 1 or pos.wincol < 1 then return end
  if vim.api.nvim_win_get_config(win).relative ~= "" then return end
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].buftype ~= "" then return end
  local ft = vim.bo[buf].filetype
  if ft == "neo-tree" or ft == "dashboard" then return end
  local width, height = vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win)
  local x = math.max(1, math.min(pos.wincol, width))
  local y = math.max(1, math.min(pos.winrow, height))
  local choices = {
    { dir = "left", distance = (x - 1) / width },
    { dir = "right", distance = (width - x) / width },
    { dir = "above", distance = (y - 1) / height },
    { dir = "below", distance = (height - y) / height },
  }
  table.sort(choices, function(a, b) return a.distance < b.distance end)
  return win, choices[1].distance <= 0.25 and choices[1].dir or "center", width, height
end

local function preview(s, win, direction, width, height)
  local key = tostring(win) .. ":" .. direction .. ":" .. width .. ":" .. height
  if s.preview_key == key and valid(s.preview_win) then return end
  close_preview(s)
  if width < 4 or height < 4 then return end
  local row, col, w, h = 0, 0, width, height
  if direction == "left" or direction == "right" then
    w = math.max(1, math.floor(width / 2))
    if direction == "right" then col = width - w end
  elseif direction == "above" or direction == "below" then
    h = math.max(1, math.floor(height / 2))
    if direction == "below" then row = height - h end
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  local label = direction == "center" and " Drop to open here " or (" Drop to split " .. direction .. " ")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { label })
  local ok, preview_win = pcall(vim.api.nvim_open_win, buf, false, {
    relative = "win", win = win, row = row, col = col, width = w, height = h,
    style = "minimal", focusable = false, mouse = false, zindex = 200,
  })
  if not ok then return end
  s.preview_buf, s.preview_win, s.preview_key = buf, preview_win, key
  vim.wo[preview_win].winblend = 65
  vim.wo[preview_win].winhighlight = "Normal:Visual"
end

local function finish(s, pos)
  if drag ~= s then return end
  drag = nil
  close_preview(s)
  if not vim.api.nvim_buf_is_valid(s.buf) then return end
  local target, direction = target_at(pos)
  if s.moved and target then
    if direction == "center" then
      vim.api.nvim_set_current_win(target)
      vim.api.nvim_win_set_buf(target, s.buf)
    else
      local ok, result = pcall(vim.api.nvim_open_win, s.buf, true, { win = target, split = direction })
      if not ok then vim.notify("Cannot split the window: " .. tostring(result), vim.log.levels.WARN) end
    end
  elseif valid(s.origin_win) then
    vim.api.nvim_set_current_win(s.origin_win)
    vim.api.nvim_win_set_buf(s.origin_win, s.buf)
  end
end

function M.press(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  if drag then close_preview(drag) end
  local s = { buf = buf, origin_win = vim.api.nvim_get_current_win(), moved = false }
  drag = s
  vim.defer_fn(function()
    if drag == s then close_preview(s); drag = nil end
  end, 30000)
end

function M.setup()
  for _, mode in ipairs({ "n", "v", "i" }) do
    vim.keymap.set(mode, "<LeftDrag>", function()
      local s = drag
      if not s then return "<LeftDrag>" end
      local pos = vim.fn.getmousepos()
      local win, direction, width, height = target_at(pos)
      if win then s.moved = true end
      vim.schedule(function()
        if drag ~= s then return end
        if win and valid(win) then preview(s, win, direction, width, height) else close_preview(s) end
      end)
      return "<Ignore>"
    end, { expr = true, replace_keycodes = true, silent = true, desc = "Drag buffer tab" })
    vim.keymap.set(mode, "<LeftRelease>", function()
      local s = drag
      if not s then return "<LeftRelease>" end
      local pos = vim.fn.getmousepos()
      vim.schedule(function() finish(s, pos) end)
      return "<Ignore>"
    end, { expr = true, replace_keycodes = true, silent = true, desc = "Drop buffer tab" })
  end
end

return M
