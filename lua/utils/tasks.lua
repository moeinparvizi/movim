-- Project tasks from VS Code's tasks.json and package.json, with separate terminals.
local M = {}
local panel = { rows = {}, runs = {} }

local function join(a, b) return vim.fs.normalize(a .. "/" .. b) end
local function exists(path) return vim.fn.filereadable(path) == 1 end
local function is_abs(path) return path:match("^%a:[/\\]") or path:match("^[/\\]") end

-- Strip JSONC comments and trailing commas without touching strings or URLs.
local function jsonc(text)
  local out, i, quoted, escaped = {}, 1, false, false
  while i <= #text do
    local ch, nextch = text:sub(i, i), text:sub(i + 1, i + 1)
    if quoted then
      out[#out + 1] = ch
      if escaped then escaped = false elseif ch == "\\" then escaped = true elseif ch == '"' then quoted = false end
    elseif ch == '"' then
      quoted = true; out[#out + 1] = ch
    elseif ch == "/" and nextch == "/" then
      out[#out + 1] = " "
      i = i + 2
      while i <= #text and text:sub(i, i) ~= "\n" do i = i + 1 end
      if i <= #text then out[#out + 1] = "\n" end
    elseif ch == "/" and nextch == "*" then
      out[#out + 1] = " "
      local ending = text:find("*/", i + 2, true)
      if not ending then error("Unterminated comment in tasks.json") end
      i = ending + 1
    else
      out[#out + 1] = ch
    end
    i = i + 1
  end
  text = table.concat(out)
  out, i, quoted, escaped = {}, 1, false, false
  while i <= #text do
    local ch = text:sub(i, i)
    if quoted then
      out[#out + 1] = ch
      if escaped then escaped = false elseif ch == "\\" then escaped = true elseif ch == '"' then quoted = false end
    elseif ch == '"' then
      quoted = true; out[#out + 1] = ch
    elseif ch == "," then
      local after = text:sub(i + 1):match("^%s*(.)")
      if after ~= "]" and after ~= "}" then out[#out + 1] = ch end
    else
      out[#out + 1] = ch
    end
    i = i + 1
  end
  return table.concat(out)
end

local function read_json(path, comments)
  if not exists(path) then return nil end
  local ok, data = pcall(function()
    local text = table.concat(vim.fn.readfile(path), "\n"):gsub("^\239\187\191", "")
    return vim.json.decode(comments and jsonc(text) or text)
  end)
  if not ok or type(data) ~= "table" then return nil, "Cannot read " .. path .. ": " .. tostring(data) end
  return data
end

local function parents(start)
  local dir, result = vim.fs.normalize(start), {}
  while dir and dir ~= "" do
    result[#result + 1] = dir
    local parent = vim.fs.dirname(dir)
    if not parent or parent == dir then break end
    dir = parent
  end
  return result
end

local function project_root(file)
  local cwd = vim.fs.normalize(vim.fn.getcwd())
  if exists(join(cwd, ".vscode/tasks.json")) then return cwd end
  local dir = file ~= "" and vim.fs.dirname(vim.fs.normalize(file)) or cwd
  local dirs = parents(dir)
  for _, p in ipairs(dirs) do
    if exists(join(p, ".vscode/tasks.json")) then return p end
    if p == cwd then break end
  end
  for _, p in ipairs(dirs) do
    if exists(join(p, "package.json")) or vim.fn.isdirectory(join(p, ".git")) == 1 or exists(join(p, ".git")) then return p end
    if p == cwd then break end
  end
  return cwd
end

local function manager(root, pkg)
  local declared = type(pkg.packageManager) == "string" and pkg.packageManager:match("^([%w_-]+)@")
  if declared and ({ npm = true, pnpm = true, yarn = true, bun = true })[declared] then return declared end
  for _, item in ipairs({ { "pnpm-lock.yaml", "pnpm" }, { "yarn.lock", "yarn" }, { "bun.lock", "bun" }, { "bun.lockb", "bun" } }) do
    if exists(join(root, item[1])) then return item[2] end
  end
  return "npm"
end

local function discover(root)
  local tasks, errors = {}, {}
  local file = join(root, ".vscode/tasks.json")
  local config, err = read_json(file, true)
  if err then errors[#errors + 1] = err end
  if config then
    if type(config.tasks) ~= "table" then
      errors[#errors + 1] = "tasks.json must contain a tasks array"
    else
      for _, raw in ipairs(config.tasks) do
        if type(raw) == "table" and raw.hide ~= true then
          local label = raw.label or raw.task or raw.script or raw.command
          if type(label) == "string" and label ~= "" then
            tasks[#tasks + 1] = { key = root .. "|vscode|" .. label, label = label, source = "VS Code", raw = raw, defaults = config.options }
          end
        end
      end
    end
  end
  local pkg, pkgerr = read_json(join(root, "package.json"), false)
  if pkgerr then errors[#errors + 1] = pkgerr end
  if pkg and type(pkg.scripts) == "table" then
    local names = vim.tbl_keys(pkg.scripts)
    table.sort(names)
    for _, name in ipairs(names) do
      if type(name) == "string" and type(pkg.scripts[name]) == "string" then
        tasks[#tasks + 1] = { key = root .. "|npm|" .. name, label = name, source = "package.json", script = name, description = pkg.scripts[name], manager = manager(root, pkg) }
      end
    end
  end
  return tasks, errors
end

local function resolve(value, root, file)
  if type(value) ~= "string" then error("Expected a string in the task definition") end
  return (value:gsub("%${([^}]+)}", function(key)
    if key == "workspaceFolder" then return root end
    if key == "workspaceFolderBasename" then return vim.fn.fnamemodify(root, ":t") end
    if key == "file" and file ~= "" then return file end
    if key == "fileDirname" and file ~= "" then return vim.fn.fnamemodify(file, ":h") end
    if key == "fileBasename" and file ~= "" then return vim.fn.fnamemodify(file, ":t") end
    local env = key:match("^env:(.+)$")
    if env and vim.env[env] ~= nil then return vim.env[env] end
    error("Unsupported or unavailable variable: ${" .. key .. "}")
  end))
end

local function prepare(task, root, file)
  if task.literal then return task.literal, root, nil end
  if task.script then
    if vim.fn.executable(task.manager) == 0 then error(task.manager .. " is not installed or not in PATH") end
    return task.manager .. " run " .. vim.fn.shellescape(task.script), root, nil
  end
  local raw = task.raw
  local platform = vim.fn.has("win32") == 1 and "windows" or (vim.fn.has("mac") == 1 and "osx" or "linux")
  local def = vim.tbl_deep_extend("force", {}, raw, type(raw[platform]) == "table" and raw[platform] or {})
  if def.dependsOn ~= nil then error("dependsOn is not supported; run the dependency separately") end
  local opts = vim.tbl_deep_extend("force", {}, type(task.defaults) == "table" and task.defaults or {}, type(def.options) == "table" and def.options or {})
  if opts.shell ~= nil then error("options.shell is not supported") end
  local cwd = resolve(opts.cwd or root, root, file)
  if not is_abs(cwd) then cwd = join(root, cwd) end
  if vim.fn.isdirectory(cwd) ~= 1 then error("Task working directory does not exist: " .. cwd) end
  local env
  if type(opts.env) == "table" then
    env = {}
    for key, value in pairs(opts.env) do env[key] = resolve(value, root, file) end
  end
  if def.type == "npm" and type(def.script) == "string" then
    local npm_root = root
    if def.path ~= nil then
      npm_root = resolve(def.path, root, file)
      if not is_abs(npm_root) then npm_root = join(root, npm_root) end
      if vim.fn.isdirectory(npm_root) ~= 1 then error("npm task folder does not exist: " .. npm_root) end
      if opts.cwd == nil then cwd = npm_root end
    end
    local pkg = read_json(join(npm_root, "package.json"), false) or {}
    local cmd = manager(npm_root, pkg)
    if vim.fn.executable(cmd) == 0 then error(cmd .. " is not installed or not in PATH") end
    return cmd .. " run " .. vim.fn.shellescape(resolve(def.script, root, file)), cwd, env
  end
  if def.type ~= nil and def.type ~= "shell" and def.type ~= "process" then
    error("Unsupported task type: " .. tostring(def.type))
  end
  if type(def.command) ~= "string" or def.command == "" then error("Task has no command") end
  local command = resolve(def.command, root, file)
  local args = {}
  if def.args ~= nil and type(def.args) ~= "table" then error("Task args must be an array") end
  for _, arg in ipairs(def.args or {}) do args[#args + 1] = resolve(arg, root, file) end
  if def.type == "process" then
    table.insert(args, 1, command)
    return args, cwd, env
  end
  for _, arg in ipairs(args) do command = command .. " " .. vim.fn.shellescape(arg) end
  return command, cwd, env
end

local function valid_panel()
  return panel.buf and vim.api.nvim_buf_is_valid(panel.buf) and panel.win and vim.api.nvim_win_is_valid(panel.win)
end

local function status(task)
  local run = panel.runs[task.key]
  if not run then return "" end
  if run.running then return " [running]" end
  return " [exit " .. tostring(run.code or "?") .. "]"
end

local function refresh()
  if not valid_panel() then return end
  local tasks, errors = discover(panel.root)
  local lines = { "TASKS", vim.fn.fnamemodify(panel.root, ":~"), "", "Enter: run  o: output  x: stop", "r: refresh  e: edit  c: command  q: close", "" }
  panel.rows = {}
  for _, source in ipairs({ "VS Code", "package.json" }) do
    lines[#lines + 1] = source == "VS Code" and ".vscode/tasks.json" or "package.json scripts"
    local count = 0
    for _, task in ipairs(tasks) do
      if task.source == source then
        count = count + 1
        lines[#lines + 1] = "  > " .. task.label .. status(task)
        panel.rows[#lines] = task
      end
    end
    if count == 0 then lines[#lines + 1] = "  (none)" end
    lines[#lines + 1] = ""
  end
  for _, err in ipairs(errors) do lines[#lines + 1] = "Error: " .. err end
  vim.bo[panel.buf].modifiable = true
  vim.api.nvim_buf_set_lines(panel.buf, 0, -1, false, lines)
  vim.bo[panel.buf].modifiable = false
end

vim.api.nvim_create_autocmd("BufWritePost", {
  group = vim.api.nvim_create_augroup("movimTasks", { clear = true }),
  callback = function(args)
    if not valid_panel() or not panel.root then return end
    local path = vim.fs.normalize(vim.api.nvim_buf_get_name(args.buf))
    if path == join(panel.root, ".vscode/tasks.json") or path == join(panel.root, "package.json") then
      vim.schedule(refresh)
    end
  end,
})

local function selected()
  if not valid_panel() then return end
  return panel.rows[vim.api.nvim_win_get_cursor(panel.win)[1]]
end

local function output(run)
  if not run or not run.buf or not vim.api.nvim_buf_is_valid(run.buf) then
    return vim.notify("No output for this task yet", vim.log.levels.INFO, { title = "Tasks" })
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(win) == run.buf then vim.api.nvim_set_current_win(win); return end
  end
  local win = panel.output_win
  if win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_tabpage(win) == vim.api.nvim_get_current_tabpage()
    and vim.b[vim.api.nvim_win_get_buf(win)].nemovim_task then
    vim.api.nvim_set_current_win(win)
  else
    -- Split the bottom task area so output stays to the left of the list.
    if valid_panel() then vim.api.nvim_set_current_win(panel.win) end
    vim.cmd("leftabove vsplit")
    panel.output_win = vim.api.nvim_get_current_win()
    if valid_panel() then vim.api.nvim_win_set_width(panel.win, math.min(42, math.floor(vim.o.columns / 2))) end
  end
  vim.api.nvim_win_set_buf(0, run.buf)
end

local function run(task)
  local previous = panel.runs[task.key]
  if previous and previous.running then return output(previous) end
  local ok, cmd, cwd, env = pcall(prepare, task, panel.root, panel.file)
  if not ok then return vim.notify(tostring(cmd), vim.log.levels.ERROR, { title = "Tasks" }) end
  local buf = vim.api.nvim_create_buf(false, false)
  vim.bo[buf].buflisted = false
  vim.bo[buf].bufhidden = "hide"
  vim.b[buf].nemovim_task = task.label
  local item = { buf = buf, running = true, label = task.label }
  panel.runs[task.key] = item
  output(item)
  local started, job = pcall(vim.fn.termopen, cmd, {
    cwd = cwd,
    env = env,
    on_exit = function(_, code)
      vim.schedule(function()
        item.running, item.code = false, code
        refresh()
      end)
    end,
  })
  if not started or type(job) ~= "number" or job <= 0 then
    item.running, item.code = false, -1
    refresh()
    return vim.notify("Could not start task: " .. tostring(job), vim.log.levels.ERROR, { title = "Tasks" })
  end
  item.job = job
  vim.bo[buf].buflisted = false
  refresh()
  vim.cmd("startinsert")
end

local function edit_tasks()
  local path = join(panel.root, ".vscode/tasks.json")
  if panel.origin and vim.api.nvim_win_is_valid(panel.origin) then vim.api.nvim_set_current_win(panel.origin) else vim.cmd("wincmd p") end
  vim.cmd.edit(vim.fn.fnameescape(path))
  if not exists(path) and vim.api.nvim_buf_line_count(0) == 1 and vim.api.nvim_get_current_line() == "" then
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      "{", '  "version": "2.0.0",', '  "tasks": [', '    {',
      '      "label": "Example task",', '      "type": "shell",', '      "command": "echo Hello from movim"',
      "    }", "  ]", "}",
    })
  end
  vim.bo.filetype = "jsonc"
end

function M.toggle()
  if valid_panel() then
    local output_win = panel.output_win
    if output_win and vim.api.nvim_win_is_valid(output_win) and output_win ~= panel.win
      and vim.api.nvim_win_get_tabpage(output_win) == vim.api.nvim_win_get_tabpage(panel.win)
      and vim.b[vim.api.nvim_win_get_buf(output_win)].nemovim_task then
      vim.api.nvim_win_close(output_win, true)
    end
    panel.output_win = nil
    if #vim.api.nvim_tabpage_list_wins(0) == 1 then
      vim.api.nvim_win_set_buf(panel.win, vim.api.nvim_create_buf(true, false))
    else
      vim.api.nvim_win_close(panel.win, true)
    end
    panel.win, panel.buf = nil, nil
    return
  end
  local file = vim.api.nvim_buf_get_name(0)
  if vim.bo.buftype ~= "" then file = "" end
  panel.file, panel.root, panel.origin = file, project_root(file), vim.api.nvim_get_current_win()
  vim.cmd("botright 12new")
  panel.win, panel.buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  vim.bo[panel.buf].buftype, vim.bo[panel.buf].bufhidden, vim.bo[panel.buf].swapfile = "nofile", "wipe", false
  vim.bo[panel.buf].buflisted = false
  vim.bo[panel.buf].filetype = "nemovim-tasks"
  vim.wo[panel.win].number, vim.wo[panel.win].relativenumber = false, false
  vim.wo[panel.win].signcolumn, vim.wo[panel.win].foldcolumn, vim.wo[panel.win].wrap = "no", "0", false
  vim.wo[panel.win].winfixheight = true
  vim.api.nvim_create_autocmd("BufEnter", { buffer = panel.buf, callback = function() vim.schedule(refresh) end })
  local function map(key, fn, desc) vim.keymap.set("n", key, fn, { buffer = panel.buf, silent = true, desc = desc }) end
  map("<CR>", function() local task = selected(); if task then run(task) end end, "Run selected task")
  map("<2-LeftMouse>", function()
    local pos = vim.fn.getmousepos()
    if pos.winid ~= panel.win or pos.line < 1 then return end
    vim.api.nvim_win_set_cursor(panel.win, { pos.line, 0 })
    local task = selected(); if task then run(task) end
  end, "Run selected task")
  map("o", function() local task = selected(); if task then output(panel.runs[task.key]) end end, "Show task output")
  map("x", function()
    local task = selected()
    local item = task and panel.runs[task.key]
    if item and item.running and item.job then vim.fn.jobstop(item.job) else vim.notify("Selected task is not running", vim.log.levels.INFO, { title = "Tasks" }) end
  end, "Stop selected task")
  map("r", refresh, "Refresh tasks")
  map("e", edit_tasks, "Edit tasks.json")
  map("c", function()
    vim.ui.input({ prompt = "Run command in " .. panel.root .. ": " }, function(value)
      if value and vim.trim(value) ~= "" then
        vim.schedule(function() run({ key = panel.root .. "|command|" .. value, label = value, literal = value }) end)
      end
    end)
  end, "Run a command")
  map("q", M.toggle, "Close tasks")
  refresh()
end

return M
