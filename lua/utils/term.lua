-- Terminal helpers (lazygit floating window)
local M = {}
local lazygit_term = nil

function M.lazygit()
  local toggleterm = require("toggleterm.terminal")
  if lazygit_term and lazygit_term:is_open() then
    lazygit_term:close()
    lazygit_term = nil
    return
  end
  require('utils.git_project').choose(function(root)
    lazygit_term = toggleterm.Terminal:new({
      cmd = "lazygit",
      dir = root,
      direction = "float",
      float_opts = { border = "rounded" },
      hidden = true,
      on_close = function()
        pcall(function() require("gitsigns").refresh() end)
      end,
    })
    lazygit_term:open()
  end)
end

return M
