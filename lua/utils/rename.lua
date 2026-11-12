local M = {}

function M.symbol()
  local clients = vim.lsp.get_clients({ bufnr = 0, method = "textDocument/rename" })
  if #clients == 0 then
    vim.notify("Rename is unavailable: no language server with rename support is attached. Check :LspInfo and open the project root.", vim.log.levels.WARN)
    return
  end

  -- Angular's server returns one semantic edit covering both TypeScript and templates.
  -- Pick one client: asking several servers would apply overlapping edits twice.
  local selected = clients[1]
  for _, client in ipairs(clients) do
    if client.name == "angularls" then selected = client; break end
    if client.name == "vtsls" then selected = client end
  end
  vim.lsp.buf.rename(nil, { filter = function(client) return client.id == selected.id end })
end

return M
