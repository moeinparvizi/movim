# movim documentation

movim is a customizable Neovim workspace for working with code in a terminal. This guide covers installation and everyday features.

## Website and documentation languages

The website opens in Persian by default. Choose **EN** for English; the preference is saved for later visits. Documentation links follow the selected language. The **فارسی** link in this guide opens the complete Persian handbook: 20 chapters and five practical references, all preserved alongside the chapter index. The Persian handbook includes the detailed tutorials rather than only this English overview.

Use `Ctrl+K`, `Cmd+K`, or `/` to search the full Persian handbook from either language. Search results remain in Persian and include content snippets and filenames. Arrow keys move between results, Enter opens a result, and Escape closes search. On mobile, use the search button and expandable chapter index. Document pages include heading permalinks, an on-page contents list, previous/next chapters, scrollable tables and code-copy buttons. The homepage has keyboard-accessible code, terminal and Git preview tabs. Webfonts are hosted with the site and respect reduced-motion preferences.

Stylesheets, scripts and the search index use content identifiers in their URLs so a new page does not reuse an incompatible cached script. Reload an already-open page after a deployment.

## Installation

Download the latest files from the [movim website](../index.html#download) or [GitHub Releases](https://github.com/moeinparvizi/movim/releases).

### Windows x64

Run `movim-Setup.exe` with the PATH option enabled, open a new PowerShell window, and run `movim` or `movim "C:\path\to\project"`. The `nvim` command remains available as an alias for the same launcher. Git for Windows is needed for Git features. The installer provides an isolated Neovim configuration and bundled tools.

### macOS: Intel and Apple Silicon

Extract `movim-macOS.zip` and run `Install.command`. The installer uses Homebrew and needs internet access. Open a new terminal and run `movim`, or pass a project path as `movim /path/to/project`. The same archive supports both architectures through Homebrew. A previous movim configuration is backed up. This package has not been tested on native macOS.

### Linux: x86_64 and ARM64

Install Neovim 0.11 or later, Git, Node.js/npm, ripgrep and curl through your distribution. A C compiler and build tools may be needed by some plugins. Then:

```sh
tar -xzf movim-linux.tar.gz
cd movim-linux
bash Install.sh
~/.local/bin/movim
```

The installer uses a separate XDG configuration and backs up a previous movim configuration. Plugin installation requires internet access. This package has not been tested on native Linux.

## First steps

Press `Space` to open the shortcut menu. Use the file explorer to browse a project. `<leader>` means Space; key availability may depend on your terminal and installed plugins.

| Shortcut | Action |
| --- | --- |
| `Space ff` | Find files |
| `Space fg` | Search text in the project |
| `Space rt` | Open project tasks |
| `Space ut` | Browse themes |
| `Space gp` | Select a remote branch and pull |
| `Space gg` | Open lazygit |
| `Space hl` / `Space hu` | Local history / undo tree |
| `gd` | Go to definition |
| `F2` or `Shift+F6` | Rename through the language server |
| `F9` in insert mode | Toggle Persian keyboard input |
| `Space ur` | Toggle the current window direction |

## Search and navigation

Find files or search text in a selected folder and exclude paths from results. Flash speeds up navigation. The file explorer supports creating, renaming and deleting files. Bookmarks help return to places in a project. Additional shortcuts are listed below; press `Space` and pause to explore the available commands.

## Editing and language tools

Completion, diagnostics, hover, definition and rename use language servers. Install the relevant language server and project dependencies for your language. Rename depends on server support; cross-file and template changes vary by server and project. Treesitter, formatting, linting, multiple cursors and snippets are also available.

## Tasks, terminals and debugging

Use the task panel to run available project tasks and scripts. The terminal panel supports multiple sessions and split views. Debugging requires a configured debugger and project-specific setup.

## Git

`Space gp` lets you select a remote branch to pull into the current branch. Conflicts can be inspected with the available diff tools. Review changes before choosing which side to keep. Git must be installed and the project must be a Git repository.

## Themes and bookmarks

Use `Space ut` to browse and select themes. Theme selection persists. Bookmarks and local history provide ways to return to important locations and earlier saved snapshots.

## Persian input and display

`F9` switches the bundled Persian keyboard in insert mode, and `Space ur` toggles the current window direction. Persian shaping and mixed right-to-left/left-to-right text depend on Neovim, the terminal and font; correct rendering in every terminal cannot be guaranteed.

movim also applies a display-only correction to common Persian and Arabic runs on left-to-right code lines. It preserves the original file text. The logical text is revealed while the cursor is inside a run; use `:PersianDisplayToggle` or `Space uP` to toggle the correction. It is not full BiDi support: lines containing ZWNJ, diacritics, Arabic-script digits or directional controls are skipped, as are terminal, wrapped, diff, right-to-left and termbidi windows. A font with Arabic Presentation Forms is required. The package includes DejaVuSansM Nerd Font Mono, which covers both the tested Persian forms and Nerd Font icons; select it as the terminal font. The Windows installer registers it for the current user. The macOS and Linux installers also install the included font files for the current user.

## Updates

movim checks for a newer stable GitHub release in the background at most once per day. Run `:MovimCheckUpdate` for a manual check. The check needs internet access and curl. It does not install updates automatically. To disable automatic checks, set `vim.g.movim_check_updates = false` before loading the configuration.

## Troubleshooting

Run `:checkhealth`, `:LspInfo` and `:ConformInfo` when diagnosing tools. Install a suitable Nerd Font in your terminal for icons. Use `:Lazy` to inspect plugin installation, `:Mason` to check installed tools, and `:messages` to inspect recent errors. If local history is empty, save the file first; snapshots are created on save.

### Persian renderer selection

Use `:PersianRenderer terminal` only with a terminal that provides bidi shaping and ordering. This disables movim's visual overlay and Neovim's Arabic shaping through `termbidi`, so the terminal receives logical Unicode. The selection is saved for subsequent sessions. Use `:PersianRenderer editor` to restore movim's limited display correction. The file contents are unchanged.

For Windows Terminal 1.18, the legacy DirectWrite renderer can be selected with `"experimental.useAtlasEngine": false` in the profile. Open a new profile instance after changing the engine. Do not assume this legacy engine option is available in newer versions. A suitable font alone cannot fix text that is reordered twice. The legacy-terminal combination requires visual verification on the target terminal.


## More shortcuts

| Shortcut | Action |
| --- | --- |
| `s` followed by two characters | Flash jump |
| `gi` / `gr` / `gy` | Implementation / references / type definition |
| `Space fr` / `Space fb` | Recent files / buffers |
| `Space f/` / `Space sr` | Search current file / replace in project |
| `Space e` | Toggle file explorer |
| `Ctrl+h/j/k/l` | Move between windows |
| `Space wv` / `Space ws` | Vertical / horizontal split |
| `Space th` / `Space tv` | Horizontal / vertical terminal |
| `gcc` | Toggle line comment |
| `Space ca` / `Space cf` | Code action / format file |
| `Space gd` / `Space gq` | Open / close diff view |
| `Space st` | Find project TODOs |
| `Space qs` / `Space ql` | Restore this project's session / the last session |
| `Space qd` | Stop saving the current session on exit |

Persistence saves sessions on exit. The mappings use lowercase `s` and `l`; `Space qS` and `Space qL` are not configured. Use `Space wh/wj/wk/wl` to move a window to the left/bottom/top/right. `Space fb` lists buffers, `Ctrl+^` switches to the alternate file, and `Space k l` lists movim bookmarks. `:Telescope keymaps` shows the mappings active in the current buffer, including mappings loaded by plugins.

## Running scripts and tests

Open movim in your project directory. `Space rr` selects a package.json script, `Space rd` runs a dev, start or serve script, and `Space rs` stops it. The runner selects pnpm, yarn, bun or npm from the lockfile. Output stays in its terminal and is not automatically parsed into quickfix. Use `Ctrl+\ Ctrl+N` to leave terminal mode.

For Jest or Vitest, install the test framework in the project and the relevant Treesitter parsers with `:TSInstall javascript typescript tsx`. `Space tn` runs the nearest test, `Space tf` runs the current file, `Space tT` runs tests in the current working directory, and `Space tS` opens results. `Space to` opens output and `Space tq` stops a run. Adapter selection uses the nearest package.json; if it declares both frameworks, Vitest is selected. Parameterized test discovery depends on adapter support.

## Debugging JavaScript

Install Node and Mason's `js-debug-adapter`. Use `Space db` to toggle a breakpoint and `Space dB` for a conditional breakpoint. Select **Launch current file** for executable JavaScript, or start Node with `--inspect=9229` and select **Attach to :9229**. TypeScript needs a suitable runtime or compiled JavaScript and source maps. `Space du` opens the debugging interface, `Space de` evaluates an expression, and `Space dx` terminates the session.

For browser debugging, start the development server yourself, select **Launch Chrome**, and provide its URL. Chrome and project source maps are required. Browser launch and interactive stepping have not been verified in this environment.


## Release consistency and recovery

The editor interface is English, including the dashboard, unnamed-file label, input indicator (`FA`) and command descriptions. Persian input and display tools remain available.

Every push to `main` starts the synchronized release workflow. It increments the shared patch version in `lua/config/version.lua`, builds Windows, macOS and Linux downloads, checks the website and documentation, and publishes the packages together. The matching website is deployed only after successful package checks. A behavior change must include both a Persian chapter update and an update to this English guide; CI blocks publication otherwise. A failed build leaves the previous successful release available.

The installer version is read from the shared Lua version file. Each package contains `release.json` with its version, source commit and SHA-256 hashes of configuration, fonts and documentation. Website and documentation pages display their source version and commit; `version.json` exposes the same information. `SHA256SUMS` on the release verifies downloaded archives.

A built-in `movim` palette is available before plugins are loaded, even without Git or a connection. The default remains TokyoNight. If a saved theme is missing on another machine, movim uses TokyoNight when installed, otherwise the bundled palette, and preserves the saved choice. Use `:Themes` to install the missing theme or `:Lazy restore` to restore plugin versions. Run `:echo g:colors_name` to see the active palette.

Windows clean-install startup and package contents are validated. CI also runs the fallback-theme check natively on macOS and Linux; interactive terminal appearance and complete macOS/Linux installation still need verification on those target systems. Optional language-server setup requires internet access.

The Windows launcher also supports installation paths containing spaces and fixes its application namespace to the bundled data directory. It does not rely on the launching shell's NVIM_APPNAME setting.
