-- Smart Git operations — the WebStorm-style workflow:
--  * smart pull  (<leader>gp): choose a remote branch, merge, resolve conflicts
--  * push        (<leader>gP)
--  * commit      (<leader>gc / <leader>gC)
--  * stash       (<leader>gs / <leader>gS)
local M = {}

local function git(args, cwd)
  cwd = cwd or vim.fn.getcwd()
  local obj = vim.system({ "git", "-C", cwd, unpack(args) }, { text = true }):wait()
  return obj.code == 0, (obj.stdout or "") .. (obj.stderr or "")
end

local function in_repo()
  local ok, _ = git({ "rev-parse", "--is-inside-work-tree" })
  return ok
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Git" })
end

local function root()
  local ok, out = git({ "rev-parse", "--show-toplevel" })
  if not ok then
    return vim.fn.getcwd()
  end
  return vim.trim(out)
end

local function operation_root()
  local lib = package.loaded["diffview.lib"]
  local view = lib and lib.get_current_view()
  return (view and view.adapter and view.adapter.ctx and view.adapter.ctx.toplevel) or root()
end

local pulling = {}

local function conflicted(cwd)
  local result = vim.system({ "git", "-C", cwd, "diff", "--name-only", "--diff-filter=U", "-z" }, { text = true }):wait()
  return result.code == 0 and (result.stdout or "") ~= ""
end

local function operation(cwd)
  local merge = git({ "rev-parse", "-q", "--verify", "MERGE_HEAD" }, cwd)
  if merge then return "merge" end
  for _, name in ipairs({ "rebase-merge", "rebase-apply" }) do
    local ok, path = git({ "rev-parse", "--git-path", name }, cwd)
    if ok then
      path = vim.trim(path)
      if not path:match("^%a:[/\\]") and not path:match("^[/\\]") then path = vim.fs.joinpath(cwd, path) end
      if vim.fn.isdirectory(path) == 1 then return "rebase" end
    end
  end
end

local function current_branch(cwd)
  local ok, branch = git({ "symbolic-ref", "--quiet", "--short", "HEAD" }, cwd)
  return ok and vim.trim(branch) or nil
end

local function unsaved_in(cwd)
  local prefix = vim.fs.normalize(cwd):gsub("/$", "") .. "/"
  if vim.fn.has("win32") == 1 then prefix = prefix:lower() end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified and vim.bo[buf].buftype == "" then
      local path = vim.fs.normalize(vim.api.nvim_buf_get_name(buf))
      if vim.fn.has("win32") == 1 then path = path:lower() end
      if path:sub(1, #prefix) == prefix then return true end
    end
  end
  return false
end

local function async_git(cwd, args, callback)
  local ok, err = pcall(vim.system, { "git", "-C", cwd, unpack(args) },
    { text = true, env = { GIT_TERMINAL_PROMPT = "0", GIT_MERGE_AUTOEDIT = "no" } },
    function(result) vim.schedule(function() callback(result) end) end)
  if not ok then
    vim.schedule(function() callback({ code = -1, stderr = tostring(err) }) end)
  end
end

local function resolve_notice(cwd)
  if not conflicted(cwd) then return false end
  local kind = operation(cwd)
  local details, next_step
  if kind == "merge" then
    details = "Left = current branch (ours); right = incoming branch (theirs)."
    next_step = "Save and stage each file, then :Gcontinue."
  elseif kind == "rebase" then
    details = "Rebase: left = upstream (ours); right = replayed local commit (theirs)."
    next_step = "Save and stage each file, then :Gcontinue."
  else
    details = "Conflicts while restoring autostash: left = merged result; right = saved local edits. The stash is retained."
    next_step = "Save and stage each file; inspect git stash list before removing the retained stash."
  end
  notify("Conflicts detected. " .. details .. "\nChoose with Space cm, Space co or Space ct. " .. next_step, vim.log.levels.WARN)
  local ok, err = pcall(vim.cmd.DiffviewOpen, { args = { "-C" .. cwd } })
  if not ok then notify("Could not open Diffview: " .. tostring(err), vim.log.levels.ERROR) end
  return true
end

function M.choose_conflict()
  local ok, lib = pcall(require, "diffview.lib")
  if not ok or not lib.get_current_view() then return notify("Open a conflicted file in Diffview first", vim.log.levels.WARN) end
  local kind = operation(operation_root())
  local choices
  if kind == "merge" then
    choices = { { label = "Left: current branch (ours)", side = "ours" }, { label = "Right: incoming branch (theirs)", side = "theirs" } }
  elseif kind == "rebase" then
    choices = { { label = "Left: upstream (ours)", side = "ours" }, { label = "Right: replayed local commit (theirs)", side = "theirs" } }
  else
    choices = { { label = "Left: merged result (ours)", side = "ours" }, { label = "Right: saved local edits (theirs)", side = "theirs" } }
  end
  vim.ui.select(choices, { prompt = "Choose a side for the conflict under the cursor:", format_item = function(item) return item.label end }, function(choice)
    if choice then require("diffview.actions").conflict_choose(choice.side)() end
  end)
end

local function start_pull(cwd, branch, remote, source)
  if pulling[cwd] then return notify("A pull is already running for this repository", vim.log.levels.WARN) end
  if current_branch(cwd) ~= branch then return notify("Current branch changed; reopen the pull picker", vim.log.levels.WARN) end
  if operation(cwd) or conflicted(cwd) then return notify("Finish or abort the current Git operation first", vim.log.levels.WARN) end
  if unsaved_in(cwd) then return notify("Save modified project buffers before pulling", vim.log.levels.WARN) end
  pulling[cwd] = true
  notify("Pulling " .. remote .. "/" .. source .. " into " .. branch .. "…")
  async_git(cwd, { "pull", "--no-rebase", "--autostash", "--no-edit", "--stat", remote, source }, function(result)
    pulling[cwd] = nil
    vim.cmd("checktime")
    pcall(function() require("gitsigns").refresh() end)
    if resolve_notice(cwd) then return end
    local output = vim.trim((result.stdout or "") .. "\n" .. (result.stderr or ""))
    if result.code == 0 then
      notify("Pull finished: " .. remote .. "/" .. source .. " → " .. branch .. "\n" .. output:sub(1, 600))
    else
      notify("Pull failed (your branch was not switched):\n" .. output:sub(1, 1000), vim.log.levels.ERROR)
    end
  end)
end

local function choose_branch(cwd, branch, remote)
  notify("Loading branches from " .. remote .. "…")
  async_git(cwd, { "ls-remote", "--heads", remote }, function(result)
    if result.code ~= 0 then return notify("Could not list remote branches:\n" .. (result.stderr or ""):sub(1, 800), vim.log.levels.ERROR) end
    local branches = {}
    for line in (result.stdout or ""):gmatch("[^\r\n]+") do
      local name = line:match("^[%x]+%s+refs/heads/(.+)$")
      if name then branches[#branches + 1] = name end
    end
    table.sort(branches)
    if #branches == 0 then return notify("No branches found on " .. remote, vim.log.levels.WARN) end
    vim.ui.select(branches, { prompt = "Pull from " .. remote .. " into " .. branch .. ":" }, function(source)
      if source then start_pull(cwd, branch, remote, source) end
    end)
  end)
end

function M.single_pull()
  if not in_repo() then return notify("Not inside a git repository", vim.log.levels.WARN) end
  local cwd = root()
  local branch = current_branch(cwd)
  if not branch then return notify("Checkout a branch before pulling (detached HEAD)", vim.log.levels.WARN) end
  if pulling[cwd] or operation(cwd) or conflicted(cwd) then return notify("Finish or abort the current Git operation first", vim.log.levels.WARN) end
  if unsaved_in(cwd) then return notify("Save modified project buffers before pulling", vim.log.levels.WARN) end
  local ok, out = git({ "remote" }, cwd)
  local remotes = {}
  if ok then for name in out:gmatch("[^\r\n]+") do remotes[#remotes + 1] = name end end
  if #remotes == 0 then return notify("No Git remote configured", vim.log.levels.WARN) end
  if #remotes == 1 then return choose_branch(cwd, branch, remotes[1]) end
  vim.ui.select(remotes, { prompt = "Remote to pull into " .. branch .. ":" }, function(remote)
    if remote then choose_branch(cwd, branch, remote) end
  end)
end

local workspace_pull_running = false
function M.pull_workspace()
  if workspace_pull_running then return notify("A workspace pull is already running", vim.log.levels.WARN) end
  if vim.fn.executable('git') ~= 1 then return notify("Git is not available in PATH", vim.log.levels.ERROR) end
  local workspace = require('utils.workspace').root or vim.fn.getcwd()
  workspace_pull_running = true
  notify("Finding Git repositories in " .. workspace .. "…")
  require('utils.git_project').discover_all(workspace, function(repos, scan_errors)
    if (require('utils.workspace').root or vim.fn.getcwd()) ~= workspace then
      workspace_pull_running = false
      return notify("Workspace changed; pull cancelled", vim.log.levels.WARN)
    end
    if #repos == 0 then workspace_pull_running = false; return notify("No repositories found" .. (#scan_errors > 0 and ("; scan errors:\n" .. table.concat(scan_errors, "\n")) or ""), vim.log.levels.WARN) end
    local index, successes, problems = 0, 0, scan_errors
    local function finish()
      workspace_pull_running = false
      local remaining = #repos - index
      local summary = ("Workspace pull: %d updated, %d need attention, %d not attempted."):format(successes, #problems, remaining)
      if #problems > 0 then summary = summary .. "\n" .. table.concat(problems, "\n") end
      notify(summary, #problems > 0 and vim.log.levels.WARN or vim.log.levels.INFO)
    end
    local next_repo
    next_repo = function()
      if (require('utils.workspace').root or vim.fn.getcwd()) ~= workspace then
        problems[#problems + 1] = "Workspace changed; remaining pulls cancelled"
        return finish()
      end
      index = index + 1
      if index > #repos then index = #repos; return finish() end
      local cwd = repos[index]
      local function skip(reason)
        problems[#problems + 1] = cwd .. ": " .. reason
        vim.schedule(next_repo)
      end
      if pulling[cwd] then return skip("pull already running") end
      if unsaved_in(cwd) then return skip("save modified editor buffers first") end
      if operation(cwd) or conflicted(cwd) then return skip("finish the existing Git operation first") end
      if not current_branch(cwd) then return skip("detached HEAD or invalid repository") end
      pulling[cwd] = true
      notify(("Pulling %d/%d: %s"):format(index, #repos, cwd))
      async_git(cwd, { "pull", "--no-rebase", "--no-autostash", "--no-edit", "--no-recurse-submodules" }, function(result)
        pulling[cwd] = nil
        vim.cmd("checktime")
        pcall(function() require("gitsigns").refresh() end)
        if conflicted(cwd) then
          problems[#problems + 1] = cwd .. ": conflicts need resolution"
          return vim.ui.select({ "Review conflicts and stop", "Continue with remaining repositories", "Stop" },
            { prompt = "Pull conflict in " .. cwd .. ":" }, function(choice)
              if choice == "Review conflicts and stop" then resolve_notice(cwd); finish()
              elseif choice == "Continue with remaining repositories" then next_repo()
              else finish() end
            end)
        end
        if result.code == 0 then successes = successes + 1
        else
          local output = vim.trim((result.stderr or "") .. "\n" .. (result.stdout or ""))
          problems[#problems + 1] = cwd .. ": " .. output:sub(1, 500)
        end
        next_repo()
      end)
    end
    next_repo()
  end)
end

function M.smart_pull()
  vim.ui.select({ "Pull all workspace repositories", "Pull a selected remote branch" },
    { prompt = "Git pull:" }, function(choice)
      if choice == "Pull all workspace repositories" then M.pull_workspace()
      elseif choice == "Pull a selected remote branch" then M.single_pull() end
    end)
end

-- Continue/abort only the operation Git actually has in progress.
function M.rebase_continue()
  local cwd = operation_root()
  if conflicted(cwd) then return notify("Resolve, save and stage every conflicted file before continuing", vim.log.levels.WARN) end
  local kind = operation(cwd)
  if not kind then return notify("No merge or rebase in progress. If an autostash conflicted, it remains in git stash list.", vim.log.levels.INFO) end
  local ok, out = git({ "-c", "core.editor=true", kind, "--continue" }, cwd)
  if ok then
    notify(kind .. " continued ✔\n" .. out:sub(1, 500))
    pcall(vim.cmd.DiffviewClose)
    resolve_notice(cwd)
  elseif not resolve_notice(cwd) then
    notify(out:sub(1, 800), vim.log.levels.WARN)
  end
end

function M.rebase_abort()
  local cwd = operation_root()
  local kind = operation(cwd)
  if not kind then return notify("No merge or rebase to abort. An autostash may still be present in git stash list.", vim.log.levels.WARN) end
  local ok, out = git({ kind, "--abort" }, cwd)
  notify(ok and (kind .. " aborted\n" .. out:sub(1, 400)) or ("Abort failed:\n" .. out:sub(1, 600)), ok and vim.log.levels.INFO or vim.log.levels.WARN)
  if ok then pcall(vim.cmd.DiffviewClose); resolve_notice(cwd) end
end

---------------------------------------------------------------
-- Push
---------------------------------------------------------------
function M.push()
  if not in_repo() then
    return notify("Not inside a git repository", vim.log.levels.WARN)
  end
  notify("Pushing…")
  local ok, out = git({ "push" })
  if ok then
    notify("Pushed ✔")
  else
    -- no upstream yet → set it
    ok, out = git({ "push", "--set-upstream", "origin", "@", })
    notify(ok and "Pushed (upstream set) ✔" or ("Push failed:\n" .. out:sub(1, 600)), ok and vim.log.levels.INFO or vim.log.levels.ERROR)
  end
end

---------------------------------------------------------------
-- Commit with a message prompt (like WebStorm's commit dialog)
---------------------------------------------------------------
function M.commit(all)
  if not in_repo() then
    return notify("Not inside a git repository", vim.log.levels.WARN)
  end
  if all then
    git({ "add", "-A" })
  end
  local staged_ok, staged = git({ "diff", "--cached", "--stat" })
  if staged_ok and vim.trim(staged) == "" then
    return notify("Nothing staged to commit. Use <leader>gC to stage all, or stage in lazygit (<leader>gg).", vim.log.levels.WARN)
  end

  vim.ui.input({ prompt = "Commit message: " }, function(msg)
    if not msg or vim.trim(msg) == "" then
      return
    end
    local ok, out = git({ "commit", "-m", msg })
    if ok then
      notify("Committed ✔ " .. msg)
      pcall(function()
        require("gitsigns").refresh()
      end)
    else
      notify(out:sub(1, 600), vim.log.levels.ERROR)
    end
  end)
end

---------------------------------------------------------------
-- Stash / unstash  (WebStorm Shelve/Unshelve)
---------------------------------------------------------------
function M.stash_push()
  local msg = "nvim-stash " .. os.date("%Y-%m-%d %H:%M:%S")
  local ok, out = git({ "stash", "push", "--include-untracked", "-m", msg })
  notify(ok and ("Stashed ✔ " .. msg) or out:sub(1, 400), ok and vim.log.levels.INFO or vim.log.levels.ERROR)
  pcall(function()
    require("gitsigns").refresh()
  end)
end

function M.stash_pop()
  local ok, out = git({ "stash", "pop" })
  notify(ok and "Stash applied ✔" or out:sub(1, 400), ok and vim.log.levels.INFO or vim.log.levels.ERROR)
  pcall(function()
    require("gitsigns").refresh()
  end)
end

function M.root()
  return root()
end

return M
