# movim documentation

movim is a customizable Neovim workspace for working with code in a terminal. This English guide covers installation and everyday features. The [complete Persian documentation](../docs/README.html) has additional detailed chapters.

## Installation

Download the latest files from the [movim website](../index.html#download) or [GitHub Releases](https://github.com/moeinparvizi/movim/releases).

### Windows x64

Run `movim-Setup.exe`, open a new PowerShell window, and run `nvim`. Git for Windows is needed for Git features. The installer provides an isolated Neovim configuration and bundled tools.

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

Find files or search text in a selected folder and exclude paths from results. Flash speeds up navigation. The file explorer supports creating, renaming and deleting files. Bookmarks help return to places in a project. See the [Persian keymap reference](../docs/14-keymaps-cheatsheet.html) for the complete list.

## Editing and language tools

Completion, diagnostics, hover, definition and rename use language servers. Install the relevant language server and project dependencies for your language. Rename depends on server support; cross-file and template changes vary by server and project. Treesitter, formatting, linting, multiple cursors and snippets are also available.

## Tasks, terminals and debugging

Use the task panel to run available project tasks and scripts. The terminal panel supports multiple sessions and split views. Debugging requires a configured debugger and project-specific setup. See the detailed [run and debug guide](../docs/run-debug-test.html) (Persian).

## Git

`Space gp` lets you select a remote branch to pull into the current branch. Conflicts can be inspected with the available diff tools. Review changes before choosing which side to keep. Git must be installed and the project must be a Git repository.

## Themes and bookmarks

Use `Space ut` to browse and select themes. Theme selection persists. Bookmarks and local history provide ways to return to important locations and earlier saved snapshots.

## Persian input and display

`F9` switches the bundled Persian keyboard in insert mode, and `Space ur` toggles the current window direction. Persian shaping and mixed right-to-left/left-to-right text depend on Neovim, the terminal and font; correct rendering in every terminal cannot be guaranteed. See [Persian support](../docs/13-persian.html) for details.

## Updates

movim checks for a newer stable GitHub release in the background at most once per day. Run `:MovimCheckUpdate` for a manual check. The check needs internet access and curl. It does not install updates automatically. To disable automatic checks, set `vim.g.movim_check_updates = false` before loading the configuration.

## Troubleshooting

Run `:checkhealth`, `:LspInfo` and `:ConformInfo` when diagnosing tools. Install a suitable Nerd Font in your terminal for icons. For more details see the [Persian troubleshooting guide](../docs/16-troubleshooting.html).
