-- Persistent line bookmarks, independent of Vim's letter marks and debug keys.
local M = {}
local entries = {}
local namespace = vim.api.nvim_create_namespace("nemovim-bookmarks")
local state_file = vim.fn.stdpath("state") .. "/nemovim-bookmarks.json"
local read_failed = false
local dirty = false

local function path_for(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" or vim.bo[buf].buftype ~= "" then return nil end
  return vim.fs.normalize(vim.fn.fnamemodify(name, ":p"))
end

local function path_key(path)
  if vim.fn.has("win32") == 1 then return path:lower() end
  return path
end

local function same_path(a, b)
  return path_key(a) == path_key(b)
end

local function sync_entry(entry)
  if not entry.buf or not vim.api.nvim_buf_is_valid(entry.buf) or not vim.api.nvim_buf_is_loaded(entry.buf) then return end
  if not same_path(path_for(entry.buf) or "", entry.path) then return end
  local pos = vim.api.nvim_buf_get_extmark_by_id(entry.buf, namespace, entry.mark, {})
  if #pos == 0 then return end
  local line = pos[1] + 1
  local text = vim.api.nvim_buf_get_lines(entry.buf, pos[1], pos[1] + 1, false)[1] or ""
  if entry.line ~= line or entry.text ~= text then dirty = true end
  entry.line, entry.text = line, text
end

local function save()
  if read_failed then return false end
  local out = {}
  for _, entry in ipairs(entries) do
    sync_entry(entry)
    out[#out + 1] = { path = entry.path, line = entry.line, text = entry.text }
  end
  if not dirty then return true end
  vim.fn.mkdir(vim.fn.fnamemodify(state_file, ":h"), "p")
  local ok, result = pcall(vim.fn.writefile, { vim.json.encode(out) }, state_file)
  if not ok or result ~= 0 then
    vim.notify("Could not save bookmarks: " .. tostring(result), vim.log.levels.ERROR)
    return false
  end
  dirty = false
  return true
end

local function load()
  if vim.fn.filereadable(state_file) == 0 then return end
  local ok, decoded = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(state_file), "\n")) end)
  if not ok or not vim.islist(decoded) then
    read_failed = true
    vim.schedule(function() vim.notify("Could not read bookmarks; the existing bookmarks file was preserved.", vim.log.levels.ERROR) end)
    return
  end
  for _, item in ipairs(decoded) do
    if type(item) == "table" and type(item.path) == "string" and type(item.line) == "number" and item.line >= 1 then
      entries[#entries + 1] = { path = item.path, line = math.floor(item.line), text = type(item.text) == "string" and item.text or "" }
    end
  end
end

local function place(entry, buf)
  if entry.buf and entry.mark and vim.api.nvim_buf_is_valid(entry.buf) then
    pcall(vim.api.nvim_buf_del_extmark, entry.buf, namespace, entry.mark)
  end
  local row = math.min(entry.line, vim.api.nvim_buf_line_count(buf)) - 1
  entry.buf = buf
  entry.mark = vim.api.nvim_buf_set_extmark(buf, namespace, row, 0, {
    sign_text = "●", sign_hl_group = "DiagnosticInfo", priority = 30, right_gravity = false,
  })
  if entry.line ~= row + 1 then dirty = true end
  entry.line = row + 1
end

local function attach(buf)
  if not vim.api.nvim_buf_is_loaded(buf) then return end
  local path = path_for(buf)
  if not path then return end
  for _, entry in ipairs(entries) do
    if same_path(entry.path, path) then
      local present = entry.buf == buf and entry.mark
        and #vim.api.nvim_buf_get_extmark_by_id(buf, namespace, entry.mark, {}) > 0
      if not present then place(entry, buf) end
    end
  end
end

local function remove(entry)
  if read_failed then
    vim.notify("Bookmarks cannot be changed until their state file can be read.", vim.log.levels.ERROR)
    return
  end
  if entry.buf and entry.mark and vim.api.nvim_buf_is_valid(entry.buf) then
    pcall(vim.api.nvim_buf_del_extmark, entry.buf, namespace, entry.mark)
  end
  for i, candidate in ipairs(entries) do
    if candidate == entry then table.remove(entries, i); break end
  end
  dirty = true
  save()
end

function M.toggle()
  if read_failed then return vim.notify("Bookmarks cannot be changed until their state file can be read.", vim.log.levels.ERROR) end
  local buf, path = vim.api.nvim_get_current_buf(), path_for(0)
  if not path then return vim.notify("Open a file before adding a bookmark.", vim.log.levels.WARN) end
  local line = vim.api.nvim_win_get_cursor(0)[1]
  for _, entry in ipairs(entries) do
    sync_entry(entry)
    if same_path(entry.path, path) and entry.line == line then
      remove(entry)
      return vim.notify("Bookmark removed", vim.log.levels.INFO)
    end
  end
  local entry = { path = path, line = line, text = vim.api.nvim_get_current_line() }
  entries[#entries + 1] = entry
  dirty = true
  place(entry, buf)
  if save() then vim.notify("Bookmark added", vim.log.levels.INFO) end
end

local function sorted_entries()
  local result = {}
  for _, entry in ipairs(entries) do sync_entry(entry); result[#result + 1] = entry end
  table.sort(result, function(a, b)
    local ap, bp = path_key(a.path), path_key(b.path)
    return ap == bp and a.line < b.line or ap < bp
  end)
  return result
end

local function jump(entry)
  if vim.fn.filereadable(entry.path) == 0 and not (entry.buf and vim.api.nvim_buf_is_valid(entry.buf)) then
    return vim.notify("Bookmark file not found: " .. entry.path, vim.log.levels.WARN)
  end
  local ok, err = pcall(vim.cmd.edit, { args = { entry.path } })
  if not ok then return vim.notify(tostring(err), vim.log.levels.ERROR) end
  vim.api.nvim_win_set_cursor(0, { math.min(entry.line, vim.api.nvim_buf_line_count(0)), 0 })
  vim.cmd("normal! zvzz")
end

function M.move(direction)
  local list = sorted_entries()
  if #list == 0 then return vim.notify("No bookmarks yet", vim.log.levels.INFO) end
  local current, line = path_for(0), vim.api.nvim_win_get_cursor(0)[1]
  local chosen
  if current then
    local key = path_key(current)
    for _, entry in ipairs(list) do
      local ek = path_key(entry.path)
      if direction > 0 and (ek > key or (ek == key and entry.line > line)) then chosen = entry; break end
      if direction < 0 and (ek < key or (ek == key and entry.line < line)) then chosen = entry end
    end
  end
  jump(chosen or (direction > 0 and list[1] or list[#list]))
end

function M.list()
  local finders = require("telescope.finders")
  local pickers = require("telescope.pickers")
  local actions = require("telescope.actions")
  local state = require("telescope.actions.state")
  local conf = require("telescope.config").values
  local function finder()
    return finders.new_table({
      results = sorted_entries(),
      entry_maker = function(entry)
        local label = vim.fn.fnamemodify(entry.path, ":~:.") .. ":" .. entry.line .. "  " .. vim.trim(entry.text or "")
        return { value = entry, display = label, ordinal = label, filename = entry.path, lnum = entry.line, col = 1 }
      end,
    })
  end
  pickers.new({}, {
    prompt_title = "Bookmarks | Enter: open | Ctrl+D: remove",
    finder = finder(),
    sorter = conf.generic_sorter({}),
    previewer = conf.grep_previewer({}),
    attach_mappings = function(buf, map)
      actions.select_default:replace(function()
        local selected = state.get_selected_entry()
        actions.close(buf)
        if selected then jump(selected.value) end
      end)
      local function delete()
        local selected = state.get_selected_entry()
        if selected then remove(selected.value); state.get_current_picker(buf):refresh(finder(), { reset_prompt = false }) end
      end
      map({ "i", "n" }, "<C-d>", delete)
      return true
    end,
  }):find()
end

function M.setup()
  load()
  local group = vim.api.nvim_create_augroup("nemovim-bookmarks", { clear = true })
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, { group = group, callback = function(args) attach(args.buf) end })
  vim.api.nvim_create_autocmd({ "BufWritePost", "BufUnload" }, { group = group, callback = function() save() end })
  vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = function() save() end })
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do attach(buf) end
  local map = function(lhs, rhs, desc) vim.keymap.set("n", lhs, rhs, { silent = true, desc = desc }) end
  map("<leader>kt", M.toggle, "Toggle bookmark")
  map("<leader>kl", M.list, "List bookmarks")
  map("<leader>kn", function() M.move(1) end, "Next bookmark")
  map("<leader>kp", function() M.move(-1) end, "Previous bookmark")
end

return M
