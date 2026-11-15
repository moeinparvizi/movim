vim.opt.rtp:prepend(vim.fn.getcwd())
local display = require("utils.persian_display")
local path = vim.fn.stdpath("state") .. "/movim/persian-renderer"
assert(vim.env.MOVIM_RENDERER_TEST == "1", "Run with a dedicated XDG_STATE_HOME")
display.set_renderer("terminal", true)
assert(vim.o.termbidi)
vim.o.termbidi = false
display.setup()
assert(vim.o.termbidi, "Saved terminal renderer must survive setup")
vim.cmd("PersianRenderer editor")
assert(not vim.o.termbidi)
assert(vim.fn.readfile(path)[1] == "editor")
local before = vim.o.termbidi
assert(not pcall(display.set_renderer, "invalid", true))
assert(vim.o.termbidi == before)
print("PASS: renderer selection, persistence and invalid value rejection")
vim.cmd("qa!")
