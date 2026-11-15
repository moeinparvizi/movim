vim.opt.rtp:prepend(vim.fn.getcwd())
local display = require("utils.persian_display")
local function same(actual, expected)
  assert(vim.deep_equal(actual, expected), vim.inspect(actual) .. " ~= " .. vim.inspect(expected))
end

local source = "const a = 'سلام دنیا'; const b = 'خطا';"
local runs = display.runs(source)
assert(#runs == 2)
same(source:sub(runs[1].start_col + 1, runs[1].end_col), "سلام دنیا")
same(runs[1].text, "ﺎﯿﻧﺩ ﻡﻼﺳ")
same(runs[2].text, "ﺎﻄﺧ")
same(display.runs("return 'می‌روم';"), {})
same(display.runs("return 'فارسی ۱۲۳';"), {})
same(display.runs("const x = 1;"), {})
print("PASS: Persian visual forms, code boundaries and unsupported sequences")
vim.cmd("qa!")
