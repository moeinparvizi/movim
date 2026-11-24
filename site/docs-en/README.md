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

Template surrounds support character and multiline selections. Blockwise selections (Ctrl+V) are refused without editing the text. A broken template file in another project cannot reuse the previous project's templates.

Live templates expand an abbreviation such as `log` with **Tab** in Insert mode. Tab/Shift+Tab navigate fields. Use `Space ct` (Normal/Visual) or `Ctrl+J` (Insert) to pick a template; Visual mode surrounds the selection. `Space cT` / `:LiveTemplatesEdit` opens the active project's `.movim/live-templates.json`. Templates reload on save; `:LiveTemplatesReload` reloads external changes. Each entry defines `abbreviation`, `description`, `filetypes`, `body` and optional `variables`. `$NAME$` fields use defaults from `variables`, repeated names mirror the same field, `$END$` sets the final cursor and `$SELECTION$` inserts selected text. Standard `${1:value}` snippet syntax also works; use one field style per template. Project entries override built-ins for the same abbreviation/filetype; `disabled: true` disables an entry and top-level `enabled: false` disables movim templates for this project. Invalid files preserve the last valid templates. JSON is read as data; executable WebStorm macros are not supported. Built-ins cover JS/TS loops, functions, imports and logging, React components, TypeScript interfaces, HTML containers, Lua and Python functions.

**Clipboard history:** `Ctrl+Shift+V` (Normal/Insert), `Space hy` or `:ClipboardHistory` opens a searchable list with a full text preview. Enter pastes at the original cursor; Ctrl+D removes an entry, Ctrl+X clears history, and Esc cancels. `:ClipboardHistoryClear` also clears it. Copies inside the editor and the current system clipboard on focus/open are captured, with Unicode, multiline and register type preserved. Earlier OS history and intermediate copies in other apps are not accessible. Each project's history and configurable `limit` (default 50, maximum 200) are stored in `.movim/settings.json` under `preferences.clipboard`; keep `.movim/` gitignored.

**Formatting:** `Space cf` / `Ctrl+Alt+L` formats the file, or selected lines in Visual mode. `Space cF` / `:FormatLine` formats the current line; `:Format` accepts an Ex range. These commands work before an LSP attaches, use installed formatters with LSP fallback, and explain missing tools through `:ConformInfo`. A formatter may expand a range to its enclosing syntax. Structure (`Space o`) uses a Neovim-compatible Aerial version and local Tree-sitter first, with LSP fallback; `:AerialInfo` reports available backends.

Press `Space` to open the shortcut menu. Use the file explorer to browse a project. `<leader>` means Space; key availability may depend on your terminal and installed plugins.

| Shortcut | Action |
| --- | --- |
| `Space ff` | Find files |
| `Space fg` | Search text in the project |
| `Space rt` | Open project tasks |
| `Space ut` | Browse themes |
| `Space gp` | Pull all workspace repositories or select a remote branch |
| `Space gg` | Open lazygit |
| `Space hl` / `Space hu` | Local history / undo tree |
| `gd` | Go to definition |
| `F2` or `Shift+F6` | Rename through the language server |
| `F9` in insert mode | Toggle Persian keyboard input |
| `Space ur` | Toggle the current window direction |

## Search and navigation

Find files or search text in a selected folder and exclude paths from results. Flash speeds up navigation. The file explorer supports creating, renaming and deleting files. Bookmarks help return to places in a project. Additional shortcuts are listed below; press `Space` and pause to explore the available commands.

Click **×** at the right of a search input or press **Ctrl+U** to clear the entire query and keep typing. This works in file search, project grep, in-file fuzzy search and Find/Replace. Repeated clicks on the clear button are supported, and clearing persistent search inputs saves the empty query. Ctrl+U replaces Telescope's preview-scroll-up shortcut; Ctrl+D selects the search folder in Find Files/Grep.

In Neo-tree, press **I** on a file/folder to hide entries with that name in the current workspace. Press **E** to edit comma-separated names and globs such as `dist, *.log, coverage`; use names, not paths. Empty the list to reset custom exclusions; the default node_modules filter remains. Filters persist independently per workspace across restarts. **H** temporarily toggles filtered items. This never deletes files, and search exclusions (Ctrl+X) are configured separately.

## Editing and language tools

Selecting a word or single-line text softly highlights its exact occurrences in the same window until the selection ends. Ctrl+Click adds or removes a cursor in Normal and Insert modes; configure the terminal to pass Ctrl+Click through if it intercepts links.

Vertical and horizontal mouse scrolling preserve the editing cursor and selection even when the cursor goes offscreen. Typing or keyboard navigation returns to that editing position; clicking visible text selects a new position. Ctrl+Click also adds a cursor in scrolled text. Scrolling another split keeps keyboard focus in the original split.

Completion, diagnostics, hover, definition and rename use language servers. Install the relevant language server and project dependencies for your language. Rename depends on server support; cross-file and template changes vary by server and project. Treesitter, formatting, linting, multiple cursors and snippets are also available.

Pause the mouse over a function, method or other symbol to see the language server's documentation in a small popup; moving the mouse or typing dismisses it. This requires a terminal that reports mouse movement and an attached server that supports hover. `K` and `Ctrl+Q` remain available for keyboard documentation.

Angular `*.component.html` templates, HTML files under an `angular.json` project and inline `@Component` templates use a bundled Angular parser for control flow such as `@if`, bindings, calls and Material tags. The selected theme supplies the colors; completion and diagnostics still require the Angular language server and project dependencies. Parsers are bundled for Windows x64, macOS Intel/Apple Silicon and Linux x64/ARM64; unsupported architectures fall back to HTML highlighting.

## Tasks, terminals and debugging

Use the task panel to run available project tasks and scripts. The terminal panel supports multiple sessions and split views. Debugging requires a configured debugger and project-specific setup.

The task panel opens at the bottom; once a task runs, its list is on the right and terminal output is on the left. Each task has its own terminal without adding an empty `[No Name]` file. Reopening a running task reuses its terminal.

## Git

Repository, pull mode, remote and branch choices open in a centered searchable popup. Type to filter, use arrow keys to navigate, and press Enter or double-click to choose; Esc cancels. Repository names include their paths. The Tasks panel uses distinct status colors, starts on the first task, and offers `/` to search and run a task in the same popup.

In workspaces containing multiple repositories, `Space gg` (lazygit), `Space gd` (Diffview), `Space ge` (Git tree) and `Space gu/gL/gb` (Git pickers) ask which project to open. `Space gc` remains the commit action. A single repository opens directly; cancel leaves the editor unchanged. Selection does not change the workspace working directory. Discovery includes the parent repository, the current file's repository and child repositories up to three levels deep, scanning at most 3,000 folders in batches. Dependencies/output folders such as node_modules, vendor, dist and build are skipped. Open a deeper project's folder as a workspace to work with it.

`Space gp` offers **Pull all workspace repositories** and the existing single-branch picker. The workspace option scans all nested folders (including worktrees and dependency folders), without following directory symlinks, then pulls repositories sequentially using each current branch's configured upstream. If the workspace is inside a repository, its containing repository is included. It merges without automatically stashing local changes; repositories with unsaved editor buffers, existing Git operations, missing upstreams, authentication errors or blocking local edits are reported and skipped. Git credentials must already be configured. A conflict popup lets you open Diffview and stop, continue with the remaining repositories, or stop. In Diffview choose the conflict under the cursor with `Space cm`, save and stage the file, then use `:Gcontinue`. If you continue past a conflict, open that repository later with `Space gd`. No conflict is resolved automatically. A summary reports successes and errors; switching workspaces cancels the remaining pulls. The single-branch option still supports choosing a remote branch and uses autostash as described in the Persian Git guide.

Repository validation runs in the background so Git cannot block editor input. Errors include Git's diagnostic output. Switching workspaces while validation is pending cancels opening the previous selection.

## Themes and bookmarks

Notifications use a restrained fade at 24 frames per second. Set `vim.g.movim_reduce_motion = true` in `user.lua` and restart to show notifications without animation. This setting does not change the terminal or personal plugins.

Use `Space ut` to browse and select themes. Theme selection persists. Bookmarks and local history provide ways to return to important locations and earlier saved snapshots.

The theme gallery uses a compact code sample for smaller windows. When pasting multiple lines into Find Files or Live Grep, the lines are joined with spaces so the whole text remains in the search field.

## Persian input and display

`F9` switches the bundled Persian keyboard in insert mode, and `Space ur` toggles the current window direction. Persian shaping and mixed right-to-left/left-to-right text depend on Neovim, the terminal and font; correct rendering in every terminal cannot be guaranteed.

movim also applies a display-only correction to common Persian and Arabic runs on left-to-right code lines. It preserves the original file text. The logical text is revealed while the cursor is inside a run; use `:PersianDisplayToggle` or `Space uP` to toggle the correction. It is not full BiDi support: lines containing ZWNJ, diacritics, Arabic-script digits or directional controls are skipped, as are terminal, wrapped, diff, right-to-left and termbidi windows. A font with Arabic Presentation Forms is required. The package includes DejaVuSansM Nerd Font Mono, which covers both the tested Persian forms and Nerd Font icons; select it as the terminal font. The Windows installer registers it for the current user. The macOS and Linux installers also install the included font files for the current user.

## Updates

After applying, movim executes the new entrypoint on the same launch, including new startup features. Slow local disk writes are allowed to finish instead of being killed by a UI timeout.

Personal temporary files beside the configuration are preserved too: updates use unique temporary names. Invalid recovery metadata stops replacement and leaves backups available for inspection.

For AI runtime upgrades, the Node.js installation must include npm on Windows, macOS and Linux.

Files are checked both when downloaded and immediately before applying, so edits made while an update is waiting are protected too. Installer upgrade checks run before copying files.

Press **u** on the dashboard, **Space u U**, or run **`:MovimUpdate`**. The latest stable release downloads in the background using Node.js, verifies the archive checksum and every manifest file, and is staged until you close all movim windows and reopen. Use **Space qq** to checkpoint drafts and quit. No uninstall is needed. Checks require curl; updates require Node.js and internet. Set `vim.g.movim_check_updates = false` in `user.lua` to disable daily checks. `:MovimCheckUpdate` only checks; downloads start when requested.

Updates replace only distributed configuration, features and documentation. Projects, workspace layouts, drafts, search history, exclusions, themes, AI data and API credentials are preserved. Put personal settings in **user.lua** beside init.lua: it loads after the main configuration and is never shipped or replaced. If a distributed file was edited, or a personal file conflicts with a newly shipped path, the update stops and lists the conflict. Move preferences to user.lua and restore/merge the original file before retrying. Git checkouts use Git instead of the installed-app updater.

Files are backed up under **.movim-update/backups/** before being changed. Write failures roll back, and an interrupted installation recovers on the next launch. Backups are retained until you remove them. For manual recovery, close movim and restore files from the chosen backup. AI editions update AI code in the same release; a changed Pi dependency is prepared with npm in staging before applying anything. Failed downloads, checksums or runtime preparation leave the installed version unchanged.

When lazy-lock.json changes, plugins are installed/restored to the release's pinned versions after startup. Internet and Git are required; run `:MovimUpdate` to retry a failed synchronization. Reopen again if an already loaded plugin changed. The lightweight update does not replace native Neovim, language tools or launchers: upgrade those by running the new installer over the existing installation, without uninstalling. New Windows installers check existing configuration for edits and back it up before upgrading; macOS/Linux installers use the same preservation engine for installations with release.json. Interactive macOS/Linux installer validation requires those platforms.

Existing regular installations made before AI was included need the unified installer once to add it. Close all editor windows and choose the existing movim installation path; keep application data and do not uninstall. Future feature updates are available inside movim.

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

Workspaces keep per-project open files, unsaved named and unnamed drafts, editor tabs, split sizes, cursors and views. `Space qp` or `:Workspaces` selects a previous project; `:WorkspaceOpen` opens a folder. `Space qS` saves a checkpoint and `Space qq` saves drafts and quits. Ordinary startup restores only the launch folder's workspace. Another recent project never replaces it automatically; use `Space qp` or `Space ql` explicitly. Passing a directory (including `movim .`) chooses it; passing a file avoids automatic restore. Global `:cd` switches workspaces; window-local `:lcd` does not. Headless installer/CLI runs do not replace interactive workspaces. Use `Space wh/wj/wk/wl` to move windows. `Space fb` lists buffers and `Ctrl+^` switches to the alternate file. `:Telescope keymaps` shows active mappings.

## Persistent workspaces and searches

Each project creates **`.movim/settings.json`** on opening. Checkpoints save open files, drafts, tabs, layout, search queries/excludes, Explorer hidden/expanded items and panel sizes after about one second of idle time, on focus loss and on exit. Internal file and search paths are relative, so copied/moved projects restore their own files; external files retain absolute paths. Add `.movim/` to your project's `.gitignore`: it contains draft text. JSON is data, never executable configuration. The recent-project index remains under `stdpath('state')/movim-workspaces/index.json`. Old central checkpoints migrate when their project is opened, preserving the original recovery copy. Invalid local settings are never overwritten with legacy data. Read-only folders report checkpoint errors.

Source files are written only with normal save commands such as `:w`; drafts remain modified after recovery. Switching projects checkpoints current drafts first. `:WorkspaceQuit` refuses to exit if checkpointing fails. `Space qd` pauses automatic saving for this run; explicit saving and switching projects still checkpoint drafts.

Hidden clean buffers remain unloaded during restoration, deferring their disk reads, FileType hooks and language servers until they are displayed. Visible files and recovered drafts load immediately.

Find Files and Grep separately remember the last query, search folders (Ctrl+D) and exclusion globs (Ctrl+X), including across application restarts. In the folder popup, choose **Add folder…** to add directories, **Remove** to remove an entry, then **Apply folders**. Multiple directories may include folders outside the project. Remove the project root to restrict searching to selected subfolders; cancelling preserves the previous scope. Clearing a value persists the empty value. Buffer Find and Replace retain their text too. Visual `Space fg` searches exactly the selected text, including Unicode; single-line selections use literal matching and multiline selections use escaped newline patterns. Normal `Space fg` reopens the last project query.

Press **Ctrl+E** on a selected Find Files or Grep result to edit the real file in the preview area. Use normal editor commands (`i` to insert); **Ctrl+S** or `:w` saves, and **Ctrl+E** returns to the search. Closing the picker preserves unsaved edits in the file buffer. Small windows without a preview use a floating editor instead.

The Visual-mode Space menu includes **Find / search**: `Space f/` searches the selection in the current file, `Space ff` seeds Find Files and `Space fg` seeds Grep. Multiline file-name selections become space-separated text. Fresh file/grep searches exclude `*.mrt, *.ttf, *.wff2, *.wff, *.woff2, *.woff, *.eot`; existing custom or deliberately empty excludes are preserved. Internal `.movim` files are excluded from searches and hidden in Explorer by default.

Neo-tree retains its resized width and the terminal panel its height. Opening terminals no longer creates extra unnamed editor buffers. Editor split sizes are restored within the available screen space; `Space w=` explicitly equalizes them. Terminal processes/output and AI conversations are not restarted after application exit.

Explorer reapplies its saved width after initial rendering and does not expand for long names. Expanded folders are saved per project. Closing the last file tab returns to the startup dashboard without quitting or closing Explorer. File-tab close, right-click and middle-click use the same safe close as `Space bd`, asking before discarding modified text. Hiding the terminal reuses its shell; closing a session frees its display number, so a newly created sole terminal is named `1` again.

TypeScript/TSX, JavaScript and Vue **type inlay hints** appear as compact `: …` labels. Click a label to see its complete server-provided type in a floating window, or press `Space uI` for type hints on the current line. Parameter-name hints remain readable. Source text is unchanged, and a connected language server is required. `Space ui` toggles all inlay hints. Type/interface declarations inside source files keep their normal folding behavior.

Within one editor process, terminal tabs belong to their project. Switching projects hides the previous panel; reopening the panel in the new project selects that project's shell. Returning to the original project makes its still-running terminals available again.

Old persistence session files contribute their project folders and open file paths without executing Vimscript or modifying the original sessions. Unsaved text never captured by the old version cannot be recovered. Legacy layouts are recorded in the new format after opening and saving. New state uses atomic replacement, caches unchanged buffer text, and skips unchanged disk writes. Invalid state is refused before closing current files. If a source file changed externally, its recovered draft opens as a separate modified unnamed buffer so the disk file is preserved. Drafts are local text snapshots; a forced process kill can lose edits newer than the last checkpoint.

## Running scripts and tests

Open movim in your project directory. `Space rr` selects a package.json script, `Space rd` runs a dev, start or serve script, and `Space rs` stops it. The runner selects pnpm, yarn, bun or npm from the lockfile. Output stays in its terminal and is not automatically parsed into quickfix. Use `Ctrl+\ Ctrl+N` to leave terminal mode.

For Jest or Vitest, install the test framework in the project and the relevant Treesitter parsers with `:TSInstall javascript typescript tsx`. `Space tn` runs the nearest test, `Space tf` runs the current file, `Space tT` runs tests in the current working directory, and `Space tS` opens results. `Space to` opens output and `Space tq` stops a run. Adapter selection uses the nearest package.json; if it declares both frameworks, Vitest is selected. Parameterized test discovery depends on adapter support.

## Debugging JavaScript

Install Node and Mason's `js-debug-adapter`. Use `Space db` to toggle a breakpoint and `Space dB` for a conditional breakpoint. Select **Launch current file** for executable JavaScript, or start Node with `--inspect=9229` and select **Attach to :9229**. TypeScript needs a suitable runtime or compiled JavaScript and source maps. `Space du` opens the debugging interface, `Space de` evaluates an expression, and `Space dx` terminates the session.

For browser debugging, start the development server yourself, select **Launch Chrome**, and provide its URL. Chrome and project source maps are required. Browser launch and interactive stepping have not been verified in this environment.


## AI panel

The standard movim installers include the AI Panel. The source and pinned runtime remain in the repository's `ai/` directory. On macOS and Linux, installation prepares the runtime with npm.

Use `Space qn` to create a named workspace, `Space qr` to rename it, and `Space qt` to switch workspaces. The project checkpoint saves their names and split layouts. `Space wv` and `Space ws` split the editor into equally sized panes with their own file labels. Alt-clicking a definition reuses its existing editor pane or opens it in the current pane.

The screen refreshes after a selection or panel closes, so its contents do not remain painted over the editor.

Use `:AIConfigure` with your provider's endpoint, exact model ID, verified context size and an API-key environment-variable name. If the key is missing, a hidden prompt asks for it. `:AIKey` lets you enter or replace it without restarting, while no requests are running. It stays in the process environment for this session and is not saved to disk or command history. Re-enter it after restarting, or export the configured variable before launching. No credentials or model subscription are bundled. GapCode/Luna availability requires a compatible provider endpoint and your own access; the independent Luna code review is not a live-provider integration test.

`Space aa` toggles the panel; Visual `Space ae` asks for a selection change in a new independent Pi tab; `Space af` attaches the current unsaved buffer. Use `:AIFile` to choose another file, `:AINew`, `:AISelect`, `:AIRename`, `:AICloseTab`, and `:AICancel` to manage chats. `:AIMove` and `:AIResize` place and size the panel. Mappings are configurable. Hiding the panel keeps conversations; closing a busy tab explicitly offers cancellation. Conversations are in-memory until editor exit.

The full buffer snapshot and exact UTF-8 selection are sent as data. Only a validated response matching its request and snapshot may be reviewed with `:AIPreview`, applied with `:AIApply`, rejected with `:AIReject`, or refined with `:AIRevise`. Apply changes only the captured selection with one Undo and never saves the file. Any intervening buffer edit blocks Apply; `:AIRerun` returns to the source for explicit reselection. Character and line selections work; block selections are refused. Stale attachments require `:AIRefresh`; oversized context stops without truncation. Common secret-file paths are denied by a configurable path policy.

Pi 0.73.1 is pinned with a lockfile and uses its official RPC protocol. Every tab runs a separate process in an empty directory with tools, extensions, skills, templates and project instruction discovery disabled. No project commands or tests run automatically. Acceptance tests use a fake adapter; integration tests use the actual pinned Pi runtime against a synthetic localhost HTTP provider. Full interactive macOS installation remains unverified on this Windows workstation; native headless checks run in CI. See the [Persian AI guide](../docs/AI-PANEL.html) for the complete workflow.

## Release consistency and recovery

The editor interface is English, including the dashboard, unnamed-file label, input indicator (`FA`) and command descriptions. Persian input and display tools remain available.

Every push to `main` starts the synchronized release workflow. It increments the shared patch version in `lua/config/version.lua`, builds Windows, macOS and Linux downloads, checks the website and documentation, and publishes the packages together. The matching website is deployed only after successful package checks. A behavior change must include both a Persian chapter update and an update to this English guide; CI blocks publication otherwise. A failed build leaves the previous successful release available.

The installer version is read from the shared Lua version file. Each package contains `release.json` with its version, source commit and SHA-256 hashes of configuration, fonts and documentation. Website and documentation pages display their source version and commit; `version.json` exposes the same information. `SHA256SUMS` on the release verifies downloaded archives.

A built-in `movim` palette is available before plugins are loaded, even without Git or a connection. The default remains TokyoNight. If a saved theme is missing on another machine, movim uses TokyoNight when installed, otherwise the bundled palette, and preserves the saved choice. Use `:Themes` to install the missing theme or `:Lazy restore` to restore plugin versions. Run `:echo g:colors_name` to see the active palette.

Windows clean-install startup and package contents are validated. CI also runs the fallback-theme check natively on macOS and Linux; interactive terminal appearance and complete macOS/Linux installation still need verification on those target systems. Optional language-server setup requires internet access.

The Windows launcher also supports installation paths containing spaces and fixes its application namespace to the bundled data directory. It does not rely on the launching shell's NVIM_APPNAME setting.
