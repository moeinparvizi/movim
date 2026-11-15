local result = {}
for name, plugin in pairs(require('lazy.core.config').plugins) do
  if plugin.url then result[name] = { url = plugin.url } end
end
vim.fn.writefile({ vim.json.encode(result) }, assert(vim.env.MOVIM_PLUGIN_EXPORT))
vim.cmd('qa!')
