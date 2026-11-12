-- Test adapters decide whether they support the current project's test files.
return {
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-lua/plenary.nvim", "nvim-neotest/nvim-nio", "nvim-treesitter/nvim-treesitter",
    "nvim-neotest/neotest-jest", "marilari88/neotest-vitest",
  },
  keys = {
    { "<leader>tn", function() require("neotest").run.run() end, desc = "Run nearest test" },
    { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run test file" },
    { "<leader>tT", function() require("neotest").run.run(vim.fn.getcwd()) end, desc = "Run test suite" },
    { "<leader>to", function() require("neotest").output.open({ enter = true }) end, desc = "Test output" },
    { "<leader>tS", function() require("neotest").summary.toggle() end, desc = "Test summary" },
    { "<leader>tq", function() require("neotest").run.stop() end, desc = "Stop test" },
  },
  config = function()
    -- Vitest reports forward-slash paths on Windows; Neotest IDs use backslashes.
    if vim.fn.has("win32") == 1 then
      local util = require("neotest-vitest.util")
      local parse = util.parsed_json_to_results
      util.parsed_json_to_results = function(...)
        local results, normalized = parse(...), {}
        for id, result in pairs(results) do
          local path, suffix = id:match("^(.-)(::.*)$")
          normalized[(path or id):gsub("/", "\\") .. (suffix or "")] = result
        end
        return normalized
      end
    end
    local function dependency(path, name)
      local root = vim.fs.root(path, "package.json")
      if not root then return false end
      local ok, pkg = pcall(function()
        return vim.json.decode(table.concat(vim.fn.readfile(root .. "/package.json"), "\n"))
      end)
      if not ok or type(pkg) ~= "table" then return false end
      local deps = vim.tbl_extend("force", pkg.dependencies or {}, pkg.devDependencies or {})
      return deps[name] ~= nil
    end
    local jest = require("neotest-jest")({})
    if vim.fn.has("win32") == 1 then
      -- Spawn the project-local Jest JavaScript entry point directly on Windows.
      local build_spec, get_results = jest.build_spec, jest.results
      jest.build_spec = function(args)
        local spec = build_spec(args)
        if not spec then return spec end
        local path = args.tree:data().path
        local root = vim.fs.root(path, "package.json")
        local entry = root and (root .. "/node_modules/jest/bin/jest.js")
        if entry and vim.fn.filereadable(entry) == 1 then
          spec.command[1] = vim.fn.exepath("node")
          table.insert(spec.command, 2, entry)
        end
        if args.tree:data().type ~= "dir" then
          spec.command[#spec.command] = path
          table.insert(spec.command, "--runTestsByPath")
        end
        return spec
      end
      jest.results = function(...)
        local results, normalized = get_results(...), {}
        for id, result in pairs(results) do
          local path, suffix = id:match("^(.-)(::.*)$")
          normalized[(path or id):gsub("/", "\\") .. (suffix or "")] = result
        end
        return normalized
      end
    end
    local vitest = require("neotest-vitest")({})
    local jest_root, vitest_root = jest.root, vitest.root
    jest.root = function(path)
      if dependency(path, "vitest") then return nil end
      if dependency(path, "jest") or dependency(path, "@jest/core") then return jest_root(path) end
    end
    vitest.root = function(path)
      if dependency(path, "vitest") then return vitest_root(path) end
    end
    require("neotest").setup({ adapters = { vitest, jest } })
  end,
}
