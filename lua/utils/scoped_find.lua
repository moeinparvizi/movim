-- Change the search root and ripgrep exclusions without losing the query.
local M = {}

local function open(state, query)
  if state.kind == "grep" then
    local args = {}
    for _, pattern in ipairs(state.exclude) do
      args[#args + 1] = "--glob"
      args[#args + 1] = "!" .. pattern
    end
    require("telescope.builtin").live_grep({
      cwd = state.cwd,
      default_text = query,
      additional_args = args,
      prompt_title = "Live Grep | Ctrl+D: folder | Ctrl+X: exclude",
      attach_mappings = function(bufnr, map) return M.attach(bufnr, map, state) end,
    })
    return
  end
  local command = { "rg", "--files", "--glob", "!.git/" }
  for _, pattern in ipairs(state.exclude) do
    command[#command + 1] = "--glob"
    command[#command + 1] = "!" .. pattern
  end
  require("telescope.builtin").find_files({
    cwd = state.cwd,
    default_text = query,
    find_command = command,
    prompt_title = "Find Files | Ctrl+D: folder | Ctrl+X: exclude",
    attach_mappings = function(bufnr, map) return M.attach(bufnr, map, state) end,
  })
end

function M.attach(prompt_bufnr, map, state, kind)
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local picker = action_state.get_current_picker(prompt_bufnr)
  state = state or { cwd = picker.cwd or vim.fn.getcwd(), exclude = {}, kind = kind or "files" }

  local function edit_scope(kind)
    local query = action_state.get_current_line()
    actions.close(prompt_bufnr)
    vim.schedule(function()
      local folder = kind == "folder"
      vim.ui.input({
        prompt = folder and "Search folder: " or "Exclude patterns (comma-separated): ",
        default = folder and state.cwd or table.concat(state.exclude, ", "),
        completion = folder and "dir" or nil,
      }, function(value)
        if value ~= nil then
          if folder then
            local path = vim.fn.expand(vim.trim(value))
            if path ~= "" and not path:match("^%a:[/\\]") and not path:match("^[/\\]") then
              path = state.cwd .. "/" .. path
            end
            if path ~= "" and vim.fn.isdirectory(path) == 1 then
              state.cwd = vim.fn.fnamemodify(path, ":p")
            else
              vim.notify("Search folder does not exist: " .. path, vim.log.levels.WARN)
            end
          else
            state.exclude = {}
            for _, pattern in ipairs(vim.split(value, ",", { plain = true, trimempty = true })) do
              pattern = vim.trim(pattern):gsub("\\", "/"):gsub("^!", "")
              if pattern ~= "" then state.exclude[#state.exclude + 1] = pattern end
            end
          end
        end
        vim.schedule(function() open(state, query) end)
      end)
    end)
  end

  for _, mode in ipairs({ "i", "n" }) do
    map(mode, "<C-d>", function() edit_scope("folder") end)
    map(mode, "<C-x>", function() edit_scope("exclude") end)
  end
  return true
end

return M
