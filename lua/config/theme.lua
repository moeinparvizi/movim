-- Theme browser: preview without saving, install optional themes, then apply.
local M = {}
local DEFAULT_THEME = "tokyonight-night"
local state_file = vim.fn.stdpath("state") .. "/colorscheme.txt"
local themes_dir = vim.fn.stdpath("data") .. "/nemovim-themes"
local previewing = false
local installing = {}

-- Preview palettes are illustrations; installed themes are previewed live.
local catalog = {
  { name = "dracula", repo = "Mofiqul/dracula.nvim", palette = { "#282a36", "#f8f8f2", "#ff79c6", "#8be9fd", "#50fa7b", "#6272a4" } },
  { name = "everforest", repo = "sainnhe/everforest", palette = { "#2d353b", "#d3c6aa", "#e67e80", "#7fbbb3", "#a7c080", "#859289" } },
  { name = "edge", repo = "sainnhe/edge", palette = { "#2c2e34", "#c5cdd9", "#b39df3", "#73b3e7", "#a1bf78", "#7c8798" } },
  { name = "nord", repo = "shaunsingh/nord.nvim", palette = { "#2e3440", "#d8dee9", "#b48ead", "#88c0d0", "#a3be8c", "#616e88" } },
  { name = "nordic", repo = "AlexvZyl/nordic.nvim", palette = { "#242933", "#d8dee9", "#b48ead", "#88c0d0", "#a3be8c", "#616e88" } },
  { name = "tokyodark", repo = "tiagovla/tokyodark.nvim", palette = { "#11121d", "#a0a8cd", "#bb9af7", "#7aa2f7", "#9ece6a", "#545c7e" } },
  { name = "github_dark", repo = "projekt0n/github-nvim-theme", palette = { "#0d1117", "#c9d1d9", "#ff7b72", "#79c0ff", "#a5d6ff", "#8b949e" } },
  { name = "github_light", repo = "projekt0n/github-nvim-theme", palette = { "#ffffff", "#24292f", "#cf222e", "#0550ae", "#116329", "#6e7781" } },
  { name = "vscode", repo = "Mofiqul/vscode.nvim", palette = { "#1e1e1e", "#d4d4d4", "#c586c0", "#dcdcaa", "#ce9178", "#6a9955" } },
}

local function persist(name)
  vim.fn.mkdir(vim.fn.fnamemodify(state_file, ":h"), "p")
  local ok, result = pcall(vim.fn.writefile, { name }, state_file)
  if not ok or result ~= 0 then
    vim.notify("Could not save the selected theme: " .. tostring(result), vim.log.levels.ERROR)
    return false
  end
  return true
end

function M.get()
  local f = io.open(state_file, "r")
  if not f then return DEFAULT_THEME end
  local name = f:read("*l") or ""
  f:close()
  return name ~= "" and name or DEFAULT_THEME
end

local function apply(name, temporary)
  previewing = temporary
  local ok, err = pcall(vim.cmd.colorscheme, name)
  previewing = false
  return ok, err
end

function M.set(name)
  local ok, err = apply(name, true)
  if not ok then
    vim.notify("Could not apply theme " .. name .. ": " .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  return persist(name)
end

local function add_installed_paths()
  for _, dir in ipairs(vim.fn.globpath(themes_dir, "*", false, true)) do
    if vim.fn.isdirectory(dir) == 1 and not dir:match("%.partial%-%d+$") then
      vim.opt.runtimepath:append(dir)
    end
  end
end

function M.catalog()
  local installed, found, result = {}, {}, {}
  for _, name in ipairs(vim.fn.getcompletion("", "color")) do installed[name] = true end
  for _, theme in ipairs(catalog) do
    local entry = vim.deepcopy(theme)
    entry.installed = installed[entry.name] or false
    found[entry.name] = true
    result[#result + 1] = entry
  end
  for name in pairs(installed) do
    if not found[name] then result[#result + 1] = { name = name, installed = true } end
  end
  table.sort(result, function(a, b) return a.name:lower() < b.name:lower() end)
  return result
end

function M.install(theme, done)
  if not theme.repo or not theme.repo:match("^[%w_.-]+/[%w_.-]+$") then
    return vim.notify("This theme has no installable repository.", vim.log.levels.ERROR)
  end
  if vim.fn.executable("git") == 0 then
    return vim.notify("Git is required to install themes.", vim.log.levels.ERROR)
  end
  if installing[theme.repo] then return vim.notify("Theme installation is already running.", vim.log.levels.INFO) end
  local id = theme.repo:gsub("/", "--")
  local target = themes_dir .. "/" .. id
  if vim.fn.isdirectory(target) == 1 then
    vim.opt.runtimepath:append(target)
    if done then done() end
    return
  end
  vim.fn.mkdir(themes_dir, "p")
  local tmp = target .. ".partial-" .. string.format("%.0f", vim.uv.hrtime())
  installing[theme.repo] = true
  vim.notify("Installing " .. theme.name .. "...", vim.log.levels.INFO)
  vim.system({ "git", "clone", "--depth=1", "https://github.com/" .. theme.repo .. ".git", tmp }, { text = true, env = { GIT_TERMINAL_PROMPT = "0" } }, function(result)
    vim.schedule(function()
      installing[theme.repo] = nil
      if result.code ~= 0 then
        vim.fn.delete(tmp, "rf")
        vim.notify("Theme installation failed: " .. vim.trim(result.stderr or "unknown error"), vim.log.levels.ERROR)
        return
      end
      local ok, err = vim.uv.fs_rename(tmp, target)
      if not ok then
        vim.fn.delete(tmp, "rf")
        vim.notify("Could not finish installing theme: " .. tostring(err), vim.log.levels.ERROR)
        return
      end
      vim.opt.runtimepath:append(target)
      vim.notify("Installed " .. theme.name, vim.log.levels.INFO)
      if done then done() end
    end)
  end)
end

local function live_palette()
  local function color(group, field, fallback)
    local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
    return hl[field] and string.format("#%06x", hl[field]) or fallback
  end
  return {
    color("Normal", "bg", "#1e1e2e"), color("Normal", "fg", "#cdd6f4"),
    color("Keyword", "fg", "#cba6f7"), color("Function", "fg", "#89b4fa"),
    color("String", "fg", "#a6e3a1"), color("Comment", "fg", "#7f849c"),
  }
end

local function preview_buffer(self, theme, original)
  local palette = theme.palette or live_palette()
  if theme.installed then
    if apply(theme.name, true) then palette = live_palette() end
  else
    apply(original, true)
  end
  local groups = { "Background", "Text", "Keyword", "Function", "String", "Comment" }
  for i, name in ipairs(groups) do
    vim.api.nvim_set_hl(0, "NemovimThemeDemo" .. name, { fg = palette[i == 1 and 2 or i], bg = palette[1], bold = i == 3 or i == 4 })
  end
  vim.wo[self.state.winid].winhighlight = "Normal:NemovimThemeDemoBackground,NormalNC:NemovimThemeDemoBackground"
  local lines = {
    "  " .. theme.name,
    theme.installed and "  Installed  ·  live editor preview" or "  Available  ·  palette illustration; Enter to install",
    "",
    "  // components/Profile.tsx",
    "  import { useState } from 'react';",
    "",
    "  type Props = { name: string };",
    "",
    "  export function Profile({ name }: Props) {",
    "    const [count, setCount] = useState(0);",
    "    return (",
    "      <button onClick={() => setCount(count + 1)}>",
    "        Hello, {name}! {count}",
    "      </button>",
    "    );",
    "  }",
    "",
    "  Enter: apply/install   Ctrl+G: GitHub   Esc: cancel",
  }
  vim.bo[self.state.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(self.state.bufnr, -1, 0, -1)
  local ns = vim.api.nvim_create_namespace("nemovim-theme-demo")
  local function paint(row, start_col, end_col, group)
    vim.api.nvim_buf_set_extmark(self.state.bufnr, ns, row - 1, start_col, { end_col = end_col, hl_group = "NemovimThemeDemo" .. group })
  end
  paint(1, 2, #lines[1], "Function")
  paint(2, 2, #lines[2], "Comment")
  paint(4, 2, #lines[4], "Comment")
  for _, row in ipairs({ 5, 7, 9, 10, 11 }) do
    local text = lines[row]
    local first, last = text:find("%a+")
    if first then paint(row, first - 1, last, "Keyword") end
  end
  paint(13, 8, #lines[13], "String")
  paint(18, 2, #lines[18], "Comment")
  vim.bo[self.state.bufnr].modifiable = false
end

function M.picker()
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local previewers = require("telescope.previewers")
  local actions = require("telescope.actions")
  local state = require("telescope.actions.state")
  local conf = require("telescope.config").values
  local original = vim.g.colors_name or M.get()
  local accepted = false
  pickers.new({}, {
    prompt_title = "Theme Gallery | Enter: apply/install | Ctrl+G: GitHub",
    layout_strategy = "horizontal",
    layout_config = { width = 0.96, height = 0.86, horizontal = { preview_cutoff = 0, preview_width = 0.55, prompt_position = "top" } },
    finder = finders.new_table({
      results = M.catalog(),
      entry_maker = function(theme)
        return { value = theme, ordinal = theme.name, display = (theme.installed and "✓  " or "↓  ") .. theme.name }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      title = "Theme demo",
      define_preview = function(self, entry) preview_buffer(self, entry.value, original) end,
    }),
    attach_mappings = function(buf, map)
      vim.api.nvim_create_autocmd("BufWipeout", {
        buffer = buf, once = true,
        callback = function() if not accepted then apply(original, true) end end,
      })
      actions.select_default:replace(function()
        local selected = state.get_selected_entry()
        if not selected then return end
        accepted = true
        actions.close(buf)
        local theme = selected.value
        if theme.installed then
          if not M.set(theme.name) then apply(original, true) end
        else
          apply(original, true)
          M.install(theme, function() if not M.set(theme.name) then apply(original, true) end end)
        end
      end)
      map({ "i", "n" }, "<C-g>", function()
        accepted = true
        actions.close(buf)
        apply(original, true)
        vim.schedule(function()
          vim.ui.input({ prompt = "GitHub theme repository (owner/repo): " }, function(value)
            if not value then return M.picker() end
            local repo = vim.trim(value):gsub("^https://github%.com/", ""):gsub("/$", ""):gsub("%.git$", "")
            if not repo:match("^[%w_.-]+/[%w_.-]+$") then
              vim.notify("Enter a GitHub repository as owner/repo.", vim.log.levels.ERROR)
              return M.picker()
            end
            M.install({ name = repo, repo = repo }, function() M.picker() end)
          end)
        end)
      end)
      return true
    end,
  }):find()
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("theme-persist", { clear = true }),
  callback = function(args) if not previewing then persist(args.match) end end,
})

function M.load()
  add_installed_paths()
  vim.schedule(function() M.set(M.get()) end)
end

vim.api.nvim_create_user_command("Themes", M.picker, { desc = "Browse and install themes" })

return M
