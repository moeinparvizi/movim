-- blink.cmp — fast autocomplete with documentation window + signature help
return {
  "saghen/blink.cmp",
  version = "1.*",
  event = { "InsertEnter", "CmdlineEnter" },
  dependencies = {
    "rafamadriz/friendly-snippets",
    {
      "L3MON4D3/LuaSnip",
      version = "v2.*",
      build = "make install_jsregexp" ,
      config = function()
        require("luasnip.loaders.from_vscode").lazy_load()
        require('utils.live_templates').reload()
      end,
    },
  },
  opts = {
    enabled = function() return vim.bo.filetype ~= "findpanel" end,
    -- Windows cannot replace a DLL loaded by another Neovim process. Using
    -- Blink's supported Lua matcher avoids download/rename races entirely.
    fuzzy = {
      implementation = vim.fn.has("win32") == 1 and "lua" or "prefer_rust_with_warning",
      prebuilt_binaries = { download = vim.fn.has("win32") == 0 },
    },
    snippets = { preset = "luasnip" },
    appearance = {
      nerd_font_variant = "normal",
      kind_icons = {
        Text = " ",
        Method = " ",
        Function = " ",
        Constructor = " ",
        Field = " ",
        Variable = "󰂧 ",
        Class = " ",
        Interface = " ",
        Module = " ",
        Property = " ",
        Unit = " ",
        Value = " ",
        Enum = " ",
        Keyword = " ",
        Snippet = " ",
        Color = " ",
        File = " ",
        Reference = " ",
        Folder = " ",
        EnumMember = " ",
        Constant = "󰏿 ",
        Struct = " ",
        Event = " ",
        Operator = "󰆕 ",
        TypeParameter = " ",
      },
    },
    completion = {
      documentation = { auto_show = true, auto_show_delay_ms = 200 },
      ghost_text = { enabled = true },
      menu = {
        draw = {
          columns = { { "kind_icon" }, { "label", gap = 1 }, { "source_name" } },
        },
      },
    },
    signature = { enabled = true },
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
    keymap = {
      preset = "enter",
      ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
      ["<Up>"] = { "select_prev", "fallback" },
      ["<Down>"] = { "select_next", "fallback" },
      ["<C-p>"] = { "select_prev", "fallback" },
      ["<C-n>"] = { "select_next", "fallback" },
      ["<C-b>"] = { "scroll_documentation_up", "fallback" },
      ["<C-f>"] = { "scroll_documentation_down", "fallback" },
      ["<Tab>"] = { function(cmp)
        if require('luasnip').locally_jumpable(1) then cmp.hide(); return cmp.snippet_forward() end
        local templates = require('utils.live_templates')
        if templates.expand(true) then cmp.hide(); vim.schedule(templates.expand); return true end
      end, "select_next", "snippet_forward", "fallback" },
      ["<S-Tab>"] = { "snippet_backward", "select_prev", "fallback" },
      ["<CR>"] = { "accept", "fallback" },
    },
  },
}
