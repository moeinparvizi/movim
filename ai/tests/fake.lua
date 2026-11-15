local M = { clients = {} }
function M.new(_, id)
  local c = { id = id, messages = {}, closed = false }
  function c:send(message, callback) self.messages[#self.messages + 1] = message; self.callback = callback end
  function c:emit(kind, value) self.callback(kind, value) end
  function c:cancel() self.closed = true end
  function c:close() self.closed = true end
  M.clients[id] = c
  return c
end
return M
