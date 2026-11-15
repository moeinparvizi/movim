-- Display-only correction for common Persian/Arabic runs in otherwise LTR lines.
-- File contents, cursor positions, registers and searches remain logical Unicode.
local forms = require("utils.persian_forms")
local M = {}
local namespace = vim.api.nvim_create_namespace("movim-persian-display")
local enabled = true
local renderer_path = vim.fn.stdpath("state") .. "/movim/persian-renderer"

-- A terminal that performs bidi must receive logical, unshaped Unicode. Sending
-- presentation forms in visual order to it applies the correction twice.
function M.set_renderer(renderer, persist)
  assert(renderer == "editor" or renderer == "terminal", "Expected editor or terminal")
  if persist then
    vim.fn.mkdir(vim.fn.fnamemodify(renderer_path, ":h"), "p")
    assert(vim.fn.writefile({ renderer }, renderer_path) == 0, "Could not save Persian renderer")
  end
  vim.o.termbidi = renderer == "terminal"
  vim.cmd("redraw!")
end

-- Each entry is a Unicode character and its byte offset in the original line.
local function split_chars(line)
  local chars = {}
  local pos = 1
  for ch in line:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    local cp = vim.fn.char2nr(ch)
    chars[#chars + 1] = { text = ch, cp = cp, byte = pos - 1, form = forms[cp] }
    pos = pos + #ch
  end
  return chars
end

local function safe_line(chars)
  for _, ch in ipairs(chars) do
    -- Avoid presenting a misleading approximation for combining marks, bidi
    -- controls, ZWNJ/ZWJ, unsupported Arabic forms or Arabic-script digits.
    if (ch.cp >= 0x600 and ch.cp <= 0x6ff and not ch.form)
      or (ch.cp >= 0x750 and ch.cp <= 0x8ff)
      or (ch.cp >= 0x200c and ch.cp <= 0x200f)
      or (ch.cp >= 0x202a and ch.cp <= 0x202e)
      or (ch.cp >= 0x2066 and ch.cp <= 0x2069) then
      return false
    end
  end
  return true
end

-- Reversing pre-shaped characters gives visual order in an LTR terminal.
local function render(chars, first, last)
  local out = {}
  local i = first
  local lam_alef = { [0x622] = { 0xfef5, 0xfef6 }, [0x623] = { 0xfef7, 0xfef8 }, [0x625] = { 0xfef9, 0xfefa }, [0x627] = { 0xfefb, 0xfefc } }
  while i <= last do
    local c = chars[i]
    local next_char = chars[i + 1]
    local ligature = c.cp == 0x644 and next_char and lam_alef[next_char.cp]
    if ligature then
      local before = chars[i - 1] and chars[i - 1].form
      local joined = before and (before[3] or before[4])
      out[#out + 1] = vim.fn.nr2char(ligature[joined and 2 or 1])
      i = i + 2
    elseif c.form then
      local before = chars[i - 1] and chars[i - 1].form
      local after = chars[i + 1] and chars[i + 1].form
      local join_before = before and (before[3] or before[4]) and (c.form[2] or c.form[4])
      local join_after = after and (c.form[3] or c.form[4]) and (after[2] or after[4])
      local index = join_before and join_after and 4 or join_before and 2 or join_after and 3 or 1
      out[#out + 1] = vim.fn.nr2char(c.form[index] or c.form[1] or c.cp)
      i = i + 1
    else
      out[#out + 1] = c.text
      i = i + 1
    end
  end
  local reversed = {}
  for i = #out, 1, -1 do reversed[#reversed + 1] = out[i] end
  return table.concat(reversed)
end

function M.runs(line)
  local chars = split_chars(line)
  if not safe_line(chars) then return {} end
  local runs, i = {}, 1
  while i <= #chars do
    if not chars[i].form then
      i = i + 1
    else
      local first = i
      i = i + 1
      while i <= #chars do
        if chars[i].form then
          i = i + 1
        elseif chars[i].text == " " and chars[i + 1] and chars[i + 1].form then
          i = i + 1
        else
          break
        end
      end
      local last = i - 1
      runs[#runs + 1] = { start_col = chars[first].byte, end_col = chars[last].byte + #chars[last].text, text = render(chars, first, last) }
    end
  end
  return runs
end

function M.setup()
  if vim.fn.filereadable(renderer_path) == 1 then
    local ok, lines = pcall(vim.fn.readfile, renderer_path)
    if ok and (lines[1] == "editor" or lines[1] == "terminal") then
      M.set_renderer(lines[1], false)
    end
  end
  vim.api.nvim_create_user_command("PersianRenderer", function(args)
    M.set_renderer(args.args, true)
    vim.notify("Persian rendering: " .. args.args .. " (saved)")
  end, {
    nargs = 1,
    complete = function() return { "editor", "terminal" } end,
    desc = "Choose and remember who shapes and orders Persian text",
  })
  vim.api.nvim_set_decoration_provider(namespace, {
    on_win = function(_, win, buf)
      local mode = vim.api.nvim_get_mode().mode
      if not enabled or mode:match("^[vV\22sS\19]") or vim.o.termbidi or not vim.o.arabicshape or not vim.api.nvim_buf_is_loaded(buf) then return false end
      if vim.bo[buf].buftype ~= "" or vim.wo[win].rightleft or vim.wo[win].diff or vim.wo[win].wrap then return false end
      return true
    end,
    on_line = function(_, win, buf, row)
      local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
      if not line or not line:find("[\216-\219]") then return end
      local cursor = vim.api.nvim_win_get_cursor(win)
      for _, run in ipairs(M.runs(line)) do
        -- Reveal the real logical text while the cursor is inside it. This
        -- avoids implying reversed visual cursor positions while editing.
        local under_cursor = cursor[1] == row + 1 and cursor[2] >= run.start_col and cursor[2] < run.end_col
        if not under_cursor then
          vim.api.nvim_buf_set_extmark(buf, namespace, row, run.start_col, {
            ephemeral = true, virt_text = { { run.text } }, virt_text_pos = "overlay", hl_mode = "combine", priority = 150,
          })
        end
      end
    end,
  })
  local cursor_inside = {}
  local group = vim.api.nvim_create_augroup("MovimPersianDisplay", { clear = true })
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "WinEnter" }, {
    group = group,
    callback = function()
      local win = vim.api.nvim_get_current_win()
      local cursor = vim.api.nvim_win_get_cursor(win)
      local line = vim.api.nvim_get_current_line()
      local inside = false
      if line:find("[\216-\219]") then
        for _, run in ipairs(M.runs(line)) do
          if cursor[2] >= run.start_col and cursor[2] < run.end_col then inside = true; break end
        end
      end
      if cursor_inside[win] ~= inside then
        cursor_inside[win] = inside
        vim.cmd("redraw!")
      end
    end,
  })
  vim.api.nvim_create_autocmd("ModeChanged", { group = group, callback = function() vim.cmd("redraw!") end })
  vim.api.nvim_create_user_command("PersianDisplayToggle", function()
    enabled = not enabled
    vim.cmd("redraw!")
    vim.notify("Persian display correction " .. (enabled and "enabled" or "disabled"))
  end, { desc = "Toggle display-only Persian correction" })
end

return M
