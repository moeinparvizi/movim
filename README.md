# movim — a Neovim-based IDE in your terminal

یک کانفیگ کامل Neovim با تمام امکاناتی که از WebStorm انتظار دارید — و بیشتر.

**📚 آموزش کامل فارسی: [docs/README.md](docs/README.md)**

## ویژگی‌های کلیدی

- 🧠 **هوشمندی کد کامل**: vtsls + angularls — اتوکامپلیت، hover، refactor، inlay hints
- 🔀 **پول هوشمند** (`<leader>gp`): autostash + rebase مثل Ctrl+T وب‌استورم؛ کانفلیکت → باز شدن خودکار Diffview با انتخاب ours/theirs/both (`co/ct/cb`)
- ✏️ **Rename هوشمند** (`S-F6`) حتی داخل template های انگولار
- 🖱️ **Alt+Click** → تعریف | **Ctrl+Click** → مولتی‌کرسر
- 🕰️ **Local History** (`<leader>hl`): اسنپ‌شات خودکار هر ذخیره + بازگردانی — عین وب‌استورم
- 🌳 **Undo Tree** ماندگار بعد از بستن (`<leader>hu`)
- 🔍 Telescope + Spectre: جستجو و جایگزینی در کل پروژه
- 🚀 پنل تسک‌ها (`<leader>rt`)، رانر npm (`<leader>rd`)، دیباگر DAP، ترمینال شناور (`Ctrl+/`)
- 🌗 ۸+ تم با ذخیره‌سازی دائمی انتخاب (`<leader>ut`) — پیش‌فرض: TokyoNight
- 🇮🇷 **تایپ فارسی استاندارد ISIRI** با F9 + نیم‌فاصله با Alt+Space
- ⚡ Flash jump (`s`)، فولدینگ ufo، Structure panel (`<leader>o`)، TODO/بوکمارک، Compare with clipboard (`<leader>Dc`)، lazygit (`<leader>gg`)

## نصب

```bash
# پیش‌نیازها (macOS)
brew install neovim node ripgrep fd lazygit
brew install --cask font-jetbrains-mono-nerd-font

# کانفیگ
mv ~/.config/nvim ~/.config/nvim.bak   # اگر قبلی دارید
git clone https://github.com/moeinparvizi/movim.git ~/.config/nvim
nvim   # اولین اجرا: پلاگین‌ها + LSP خودکار نصب می‌شوند
```

یا: `bash <(curl -s https://raw.githubusercontent.com/moeinparvizi/neovim/main/install.sh)`

## پشته فناوری

| بخش | ابزار |
|---|---|
| Manager | lazy.nvim |
| Completion | blink.cmp + friendly-snippets |
| LSP | nvim-lspconfig + mason (vtsls, angularls, tailwindcss, html, cssls, emmet, jsonls, yamlls, pyright, lua_ls, bashls, docker) |
| Highlight | Treesitter (20 پارسر) |
| Files/Grep | neo-tree + Telescope + ripgrep |
| Motion | flash.nvim |
| Git | gitsigns + diffview + git-conflict + lazygit |
| Format/Lint | conform (prettierd) + nvim-lint (eslint_d) |
| Debug | nvim-dap + dap-ui (js-debug-adapter) |
| UI | tokyonight + bufferline + lualine + ufo + aerial + dropbar + trouble + notify + dashboard |
| Editing | Comment + mini.pairs/surround/align + ts-autotag + multiple-cursors |

## کلیدهای طلایی (cheat-sheet کامل: [docs/14-keymaps-cheatsheet.md](docs/14-keymaps-cheatsheet.md))

```
<leader>gp   پول هوشمند (autostash, کانفلیکت → Diffview)     Ctrl+T
<leader>gg   lazygit                                          Git window
<leader>gc   کامیت                                            Ctrl+K
S-F6 / F2    rename هوشمند                                    Shift+F6
gd / Alt+Click  تعریف                                         Ctrl+B / Ctrl+Click
Ctrl+Click   مولتی‌کرسر                                       Alt+Click
K            مستندات hover                                    Ctrl+Q
<leader>ca   quick fix                                        Alt+Enter
<leader>hl   Local History                                    Local History
<leader>hu   Undo tree                                        Ctrl+Shift+Z tree
<leader>ff / fg   فایل / متن                                 Double Shift
<leader>o    Structure panel                                  Structure
<leader>ut   انتخاب تم (persist)                              Theme
<leader>Dc   مقایسه فایل با کلیپ‌بورد                          Compare with Clipboard
F9 (insert)  تایپ فارسی ISIRI                                 —
<leader>rd   dev server                                       Run
F5/F10/F11   دیباگ                                            Debug
Ctrl+/       ترمینال شناور                                    Terminal
```

`<leader>` = Space — هر کلیدی را نگه دارید، which-key منو باز می‌کند؛ چیزی برای حفظ کردن نیست.

## مجوز

MIT — [LICENSE](LICENSE)


## Windows: installed isolated workspace

Run [start-webstorm.cmd](start-webstorm.cmd) from PowerShell, cmd, or Explorer, optionally passing a project directory: `.\start-webstorm.cmd C:\path\to\project`. It uses portable Neovim and Node from the sibling `../.tools` directory, and keeps plugin data, Mason packages and state in `../.isolated`. Git is used from its standard Windows install or PATH; ripgrep is needed for project search. The launcher only changes environment variables in its own process and does not replace your existing configuration. To revert, close the launched editor and use your normal Neovim; the two workspace directories can be removed separately if no longer wanted. If moving this repository without the sibling directories, install Neovim 0.11+, Node/npm, Git, ripgrep, a C compiler, and optionally lazygit, pnpm, yarn and bun and follow the general installation guide.

Lazy.nvim uses [lazy-lock.json](lazy-lock.json) to pin plugins. Mason may install language servers and formatters on first use; restart Neovim after installation. Explicit `:TSInstall javascript typescript tsx html css scss json yaml markdown markdown_inline vue svelte` installs parsers when a compiler is available; these parsers were installed in this workspace. Project-local Prettier and ESLint configuration takes priority. Space uf toggles format-on-save; Space so explicitly requests organize imports.

See [WebStorm feature comparison](docs/webstorm-parity.md), [keymaps](docs/keymaps.md), and [run/debug/test guide](docs/run-debug-test.md). No project script or test runs on opening a project.

Validation in this workspace: Neovim 0.12.6 with Node 22.23.5 started headlessly; a TypeScript fixture attached vtsls and received a type error, Vue and Svelte servers attached, Prettier reformatted a fixture, ESLint reported a project-configured diagnostic, Vitest nearest and suite runs and a Jest file run passed, and Node DAP stopped at a breakpoint. These are headless checks: terminal key delivery, UI and Chrome debugging still need interactive verification. Run `:checkhealth`, `:LspInfo` and `:ConformInfo` for local diagnostics.
