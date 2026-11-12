-- DAP — debugger for Node/JS/TS (Next, Express, Nest, React via node)
-- F5 start/continue · F10 step over · F11 step in · <S-F11> step out · <leader>db breakpoint
return {
  "mfussenegger/nvim-dap",
  dependencies = {
    { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" }, opts = {} },
    { "theHamsta/nvim-dap-virtual-text", opts = {} },
  },
  keys = {
    { "<F5>", function() require("dap").continue() end, desc = "Debug: start/continue" },
    { "<F10>", function() require("dap").step_over() end, desc = "Debug: step over" },
    { "<F11>", function() require("dap").step_into() end, desc = "Debug: step into" },
    { "<S-F11>", function() require("dap").step_out() end, desc = "Debug: step out" },
    { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle breakpoint" },
    { "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input("Condition: ")) end, desc = "Conditional breakpoint" },
    { "<leader>dx", function() require("dap").terminate() end, desc = "Stop debugging" },
    { "<leader>du", function() require("dapui").toggle() end, desc = "Toggle debug UI" },
    { "<leader>de", function() require("dapui").eval() end, desc = "Evaluate expression", mode = { "n", "v" } },
    { "<leader>dr", function() require("dap").repl.toggle() end, desc = "Toggle REPL" },
  },
  config = function()
    local dap = require("dap")

    -- js-debug-adapter (installed via Mason)
    local adapter_js = vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js"
    local command = vim.fn.filereadable(adapter_js) == 1 and "node" or "js-debug-adapter"
    local args = command == "node" and { adapter_js, "${port}" } or { "${port}" }
    dap.adapters["pwa-node"] = {
      type = "server",
      host = "localhost",
      port = "${port}",
      executable = {
        command = command,
        args = args,
      },
    }
    dap.adapters["pwa-chrome"] = dap.adapters["pwa-node"]
    for _, ft in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact" }) do
      dap.configurations[ft] = {
        {
          type = "pwa-node",
          request = "launch",
          name = "Launch current file",
          cwd = "${workspaceFolder}",
          runtimeExecutable = "node",
          program = "${file}",
          sourceMaps = true,
          console = "internalConsole",
        },
        {
          type = "pwa-node",
          request = "attach",
          name = "Attach to :9229 (npm run dev/debug)",
          port = 9229,
          cwd = "${workspaceFolder}",
          restart = true,
          sourceMaps = true,
        },
        {
          type = "pwa-chrome",
          request = "launch",
          name = "Launch Chrome (start web server first)",
          url = function() return vim.fn.input("URL: ", "http://localhost:3000") end,
          webRoot = "${workspaceFolder}",
          sourceMaps = true,
        },
      }
    end

    dap.listeners.after.event_initialized["dapui_config"] = function()
      require("dapui").open()
    end
    dap.listeners.before.event_terminated["dapui_config"] = function()
      require("dapui").close()
    end
    dap.listeners.before.event_exited["dapui_config"] = function()
      require("dapui").close()
    end
  end,
}
