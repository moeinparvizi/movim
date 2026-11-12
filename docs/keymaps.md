# WebStorm keymap: Windows/Linux

Reference: [JetBrains DEFAULT WINDOWS & LINUX KEYMAP](https://resources.jetbrains.com/storage/products/webstorm/docs/WebStorm_ReferenceCard_Windows_Linux.pdf). Leader is Space. The default keymap above was checked against the official reference card. Terminal key delivery has not been tested interactively. In a terminal, Ctrl+Shift, Alt and Shift+function keys may not be distinguishable; use the fallback. Double Shift is not available as a terminal key event. The WebStorm layer can be disabled by setting `vim.g.webstorm_keymaps = false` before loading config.keymaps.

| Action | WebStorm shortcut | Neovim shortcut | Mode | Fallback | Notes |
|---|---|---|---|---|---|
| Search Everywhere | Shift twice | separate pickers | N | Space ff / fg / sc / sS | No combined picker |
| Find file | Ctrl+Shift+N | Ctrl+Shift+N | N, I | Space ff | Terminal support varies |
| Parameter info | Ctrl+P | Ctrl+P | N, I | :lua vim.lsp.buf.signature_help() | Requires LSP |
| Quick documentation | Ctrl+Q | Ctrl+Q | N, I | K | May be intercepted by terminal flow control |
| Find action | Ctrl+Shift+A | Ctrl+Shift+A | N, I | Space sc | Telescope commands, not IDE settings |
| Find in project | Ctrl+Shift+F | Ctrl+Shift+F | N, I | Space fg | Requires ripgrep |
| Recent files | Ctrl+E | Ctrl+E | N, I | Space fr | Overrides Vim scroll-down in Normal mode |
| Next/previous issue | F2 / Shift+F2 | ]d / [d | N | Shift+F2 (previous, N/I) | Requires diagnostics |
| Context action | Alt+Enter | Alt+Enter | N, I | Space ca | LSP must support it |
| Rename | Shift+F6 | Shift+F6 / F2 | N, I | Space cr / :RenameSymbol | LSP semantic rename; terminal must send the key |
| Find usages | Alt+F7 | Alt+F7 | N, I | gr | LSP references |
| Go to declaration | Ctrl+B | Ctrl+B | N, I | gd | Overrides Vim page-up |
| Implementation / type declaration | Ctrl+Alt+B / Ctrl+Shift+B | same | N, I | gi / gy | LSP support required |
| File structure | Ctrl+F12 | Ctrl+F12 | N, I | Space ss | LSP symbols |
| Debug continue | F9 | F9 | N | F5 | F9 toggles Persian in Insert mode |
| Debug step over / into | F8 / F7 | F8 / F7 | N, I | F10 / F11 | Adapter required |
| Debug step out / breakpoint | Shift+F8 / Ctrl+F8 | same | N, I | Shift+F11 / Space db | Terminal support varies |
| Organize imports | Ctrl+Alt+O | Space so | N | Space cA | Server support required |
| Run nearest/file/suite tests | Ctrl+Shift+F10 / project configuration | Space tn / tf / tT | N | Space rr for project scripts | Vitest and Jest; see run/debug/test guide |

Insert-mode IDE mappings leave Insert mode. Escape returns to Normal mode; enter Insert with i. Terminal mode uses Ctrl+\ Ctrl+N to return to Normal. `j` and `k` move display lines; `n`, `N`, Ctrl+D/U recenter; Q is disabled; visual J/K move lines and visual paste preserves the register. Ctrl+H/J/K/L navigate windows. Ctrl+B invokes LSP declaration instead of Vim page-up. These replace standard Vim behavior. Plugin mappings remain in plugin specs; use Space sk to search active mappings. On older terminals Ctrl+Shift keys can collapse into Ctrl keys and conflict; use a terminal supporting extended keyboard protocols, or use the Space fallbacks.
