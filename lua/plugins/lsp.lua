-- LSP: Mason (server installer) + nvim-lspconfig (new vim.lsp.config API)
-- Angular / React / Next / Node / Express / Nest support via vtsls + angularls.
return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    { "mason-org/mason.nvim", opts = {} },
    {
      "mason-org/mason-lspconfig.nvim",
      opts = {
        ensure_installed = {
          "vtsls", -- TypeScript/JavaScript: React, Next, Node, Express, Nest
          "vue_ls",
          "svelte",
          "angularls", -- Angular (also renames inside .html templates!)
          "tailwindcss", -- class autocomplete + sorting
          "html",
          "cssls",
          "emmet_ls",
          "jsonls",
          "yamlls",
          "dockerls",
          "docker_compose_language_service",
          "bashls",
          "pyright",
          "lua_ls",
        },
        automatic_enable = false, -- enable configured servers below, avoiding non-LSP tools
      },
    },
    "b0o/schemastore.nvim",
    "saghen/blink.cmp",
  },
  config = function()
    require('utils.inlay_hints').setup()
    local capabilities = {}
    pcall(function()
      capabilities = require("blink.cmp").get_lsp_capabilities()
    end)

    local on_attach = function(client, bufnr)
      require('utils.inlay_hints').attach(client, bufnr)
      -- Inlay hints (parameter names etc.) — toggle with <leader>ui
      if vim.lsp.inlay_hint then
        pcall(vim.lsp.inlay_hint.enable, true, { bufnr = bufnr })
      end

      local map = function(lhs, rhs, desc)
        vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = desc, silent = true })
      end
      map("gd", "<cmd>Telescope lsp_definitions<CR>", "Go to definition")
      map("gD", vim.lsp.buf.declaration, "Go to declaration")
      map("gi", "<cmd>Telescope lsp_implementations<CR>", "Go to implementation")
      map("gr", "<cmd>Telescope lsp_references<CR>", "Find references")
      map("gy", "<cmd>Telescope lsp_type_definitions<CR>", "Go to type definition")
      map("K", vim.lsp.buf.hover, "Hover documentation")
      map("<C-w>d", vim.lsp.buf.definition, "Definition (split)")
      map("<leader>ca", vim.lsp.buf.code_action, "Code actions")
      map("<leader>cA", function()
        vim.lsp.buf.code_action({ context = { only = { "source" } }, apply = true })
      end, "Source actions (fix all, organize imports…)")
      map("<leader>cR", function()
        vim.lsp.buf.code_action({ context = { only = { "refactor" } } })
      end, "Refactor this…")
      map("<leader>cl", "<cmd>LspInfo<CR>", "LSP info")
      map("[d", function()
        vim.diagnostic.jump({ count = -1, float = true })
      end, "Previous diagnostic")
      map("]d", function()
        vim.diagnostic.jump({ count = 1, float = true })
      end, "Next diagnostic")
      map("<leader>cd", vim.diagnostic.open_float, "Show diagnostic")
    end

    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("webstorm-lsp-attach", { clear = true }),
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client then on_attach(client, args.buf) end
      end,
    })

    -- Global diagnostic look
    vim.diagnostic.config({
      severity_sort = true,
      float = { border = "rounded", source = "if_many" },
      underline = { severity = vim.diagnostic.severity.ERROR },
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = "E",
          [vim.diagnostic.severity.WARN] = "W",
          [vim.diagnostic.severity.HINT] = "H",
          [vim.diagnostic.severity.INFO] = "I",
        },
      },
      virtual_text = {
        spacing = 4,
        source = "if_many",
        prefix = "●",
      },
    })


    local servers = {
      "vtsls",
      "vue_ls",
      "svelte",
      "angularls",
      "tailwindcss",
      "html",
      "cssls",
      "emmet_ls",
      "jsonls",
      "yamlls",
      "dockerls",
      "docker_compose_language_service",
      "bashls",
      "pyright",
    }

    for _, server in ipairs(servers) do
      vim.lsp.config(server, {
        capabilities = capabilities,
      })
    end

    -- Vue uses vue_ls for templates and vtsls with the Vue TypeScript plugin.
    local vue_path = vim.fn.stdpath("data") .. "/mason/packages/vue-language-server/node_modules/@vue/language-server"
    local vue_cmd = vim.fn.exepath("vue-language-server")
    if vim.fn.isdirectory(vue_path) == 0 and vue_cmd ~= "" then
      vue_path = vim.fn.fnamemodify(vue_cmd, ":h:h") .. "/@vue/language-server"
    end
    -- Server-specific settings
    vim.lsp.config("vtsls", {
      filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue" },
      settings = {
        vtsls = { tsserver = { globalPlugins = { { name = "@vue/typescript-plugin", location = vue_path, languages = { "vue" }, configNamespace = "typescript" } } } },
        javascript = {
          inlayHints = {
            parameterNames = { enabled = "literals" },
            variableTypes = { enabled = true },
            propertyDeclarationTypes = { enabled = true },
            functionLikeReturnTypes = { enabled = false },
            enumMemberValues = { enabled = true },
          },
          updateImportsOnFileMove = { enabled = "always" },
          preferences = { importModuleSpecifierPreference = "non-relative" },
        },
        typescript = {
          inlayHints = {
            parameterNames = { enabled = "literals" },
            variableTypes = { enabled = true },
            propertyDeclarationTypes = { enabled = true },
            functionLikeReturnTypes = { enabled = false },
            enumMemberValues = { enabled = true },
          },
          updateImportsOnFileMove = { enabled = "always" },
          preferences = { importModuleSpecifierPreference = "non-relative" },
        },
      },
    })

    vim.lsp.config("jsonls", {
      settings = {
        json = {
          schemas = require("schemastore").json.schemas(),
          validate = { enable = true },
        },
      },
    })

    vim.lsp.config("yamlls", {
      settings = {
        yaml = {
          schemaStore = { enable = true, url = "" },
          schemas = require("schemastore").yaml.schemas(),
        },
      },
    })

    vim.lsp.config("lua_ls", {
      capabilities = capabilities,
      settings = {
        Lua = {
          workspace = { checkThirdParty = false },
          completion = { callSnippet = "Replace" },
          hint = { enable = true },
          diagnostics = { globals = { "vim" } },
        },
      },
    })

    for _, server in ipairs(servers) do
      local cfg = vim.lsp.config[server]
      local available = type(cfg.cmd) == "table" and vim.fn.executable(cfg.cmd[1]) == 1
      if server == "svelte" then available = vim.fn.executable("svelteserver") == 1 end
      if server == "angularls" then available = vim.fn.executable("ngserver") == 1 end
      if available then
        vim.lsp.enable(server)
      end
    end
    if vim.fn.executable("lua-language-server") == 1 then vim.lsp.enable("lua_ls") end

    vim.lsp.config("emmet_ls", {
      filetypes = {
        "html",
        "htmlangular",
        "typescriptreact",
        "javascriptreact",
        "css",
        "sass",
        "scss",
        "less",
        "angular",
      },
    })
  end,
}
