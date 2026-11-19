-- Angular templates need the Angular grammar, including when they use @if.
local M = {}
function M.setup()
  vim.filetype.add({ pattern = {
    ['.*%.component%.html'] = 'htmlangular',
    ['.*%.html'] = { function(path)
      if path and vim.fs.root(path, 'angular.json') then return 'htmlangular' end
    end, { priority = 1 } },
  } })
  local system = vim.uv.os_uname().sysname
  local osname = system == 'Windows_NT' and 'windows' or system == 'Darwin' and 'macos' or system == 'Linux' and 'linux'
  local arch = jit.arch == 'x64' and 'x64' or jit.arch == 'arm64' and 'arm64'
  local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
  local path = osname and arch and vim.fs.joinpath(root, 'parsers', osname .. '-' .. arch, 'angular.so')
  local ok, loaded = false, false
  if path and vim.fn.filereadable(path) == 1 then ok, loaded = pcall(vim.treesitter.language.add, 'angular', { path = path }) end
  if ok and loaded then
    vim.treesitter.language.register('angular', 'htmlangular')
  else
    -- Standard HTML highlighting remains available on unsupported platforms.
    vim.treesitter.language.register('html', 'htmlangular')
  end
end
return M
