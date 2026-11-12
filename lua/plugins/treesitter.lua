-- Neovim 0.12 requires the current Tree-sitter API, not the obsolete master branch.
return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  config = function(plugin)
    require("nvim-treesitter").setup()
    -- Also use the bundled queries with parsers installed by older movim versions.
    vim.opt.runtimepath:append(plugin.dir .. "/runtime")

    vim.api.nvim_create_autocmd("FileType", {
      callback = function(args)
        local ft = vim.bo[args.buf].filetype
        local js = vim.tbl_contains({ "javascript", "javascriptreact", "typescript", "typescriptreact" }, ft)
        local ok = pcall(vim.treesitter.start, args.buf)
        if js then
          vim.bo[args.buf].indentexpr = ""
          vim.bo[args.buf].autoindent = true
          vim.bo[args.buf].smartindent = true
        elseif ok then
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
