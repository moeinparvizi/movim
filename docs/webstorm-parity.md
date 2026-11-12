# WebStorm capability comparison

Baseline: JetBrains **DEFAULT WINDOWS & LINUX KEYMAP**. Status describes the configuration, not a successful runtime test. No interactive testing was possible in the current environment. See [keymaps](keymaps.md) for modes and fallbacks.

| WebStorm capability | Official documentation | Neovim approach | Shortcut | Status | Difference |
|---|---|---|---|---|---|
| Search Everywhere | [Search Everywhere](https://www.jetbrains.com/help/webstorm/searching-everywhere.html) | Telescope separate pickers | Space ff/fg/sc/sS | Approximate | No unified results or double Shift |
| Project view | [Project tool window](https://www.jetbrains.com/help/webstorm/project-tool-window.html) | neo-tree | Space e | Approximate | Different project model |
| Navigation and usages | [Navigation](https://www.jetbrains.com/help/webstorm/navigating-through-the-source-code.html) | LSP and Telescope | gd, gr, gi | Approximate | Depends on server |
| Completion | [Code completion](https://www.jetbrains.com/help/webstorm/auto-completing-code.html) | blink.cmp and LSP | completion menu | Approximate | No JetBrains engine |
| Inspections | [Code inspections](https://www.jetbrains.com/help/webstorm/code-inspection.html) | LSP diagnostics and eslint_d | F2, Space xx | Approximate | Different inspection coverage |
| Refactoring | [Refactoring](https://www.jetbrains.com/help/webstorm/refactoring-source-code.html) | LSP rename and code actions | Space cr / cR | Approximate | Only server-provided semantic actions |
| Formatting | [Reformat code](https://www.jetbrains.com/help/webstorm/reformat-and-rearrange-code.html) | conform and Prettier | Space cf / uf | Approximate | Project formatter required; save formatting can be disabled |
| Git | [Git](https://www.jetbrains.com/help/webstorm/using-git-integration.html) | gitsigns, diffview, lazygit | Space gg | Approximate | lazygit is optional |
| Run scripts | [npm](https://www.jetbrains.com/help/webstorm/using-npm.html) | package.json script selector | Space rr | Approximate | No WebStorm run configuration model |
| Test nearest/file/suite | [Testing](https://www.jetbrains.com/help/webstorm/testing-your-applications.html) | neotest with Jest/Vitest | Space tn/tf/tT | Approximate | Requires project dependencies and Treesitter; nearest Vitest, suite Vitest and file Jest tested headlessly |
| Debug | [Debugging](https://www.jetbrains.com/help/webstorm/debugging-code.html) | nvim-dap + js-debug-adapter | F9, Space db | Approximate | Node breakpoint tested headlessly; Chrome launch configured but untested |
| Frameworks | [JavaScript frameworks](https://www.jetbrains.com/help/webstorm/javascript-specific-guidelines.html) | vtsls, vue_ls and svelte | LSP mappings | Approximate | All three servers attached in fixtures; framework intelligence differs |

Implementation references: [Neovim LSP](https://neovim.io/doc/user/lsp.html), [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig), [lazy.nvim](https://github.com/folke/lazy.nvim), [conform.nvim](https://github.com/stevearc/conform.nvim), [nvim-dap](https://github.com/mfussenegger/nvim-dap), [mason-lspconfig](https://github.com/mason-org/mason-lspconfig.nvim). Other existing plugins have not yet been individually audited against their current documentation.
