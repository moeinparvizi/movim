# movim — a Neovim workspace for your terminal

movim brings project navigation, language tools, Git, terminals, tasks, themes, and bookmarks together in a customizable Neovim configuration.

[Website and downloads](https://moeinparvizi.github.io/movim/) · [English guide](https://moeinparvizi.github.io/movim/docs-en/README.html) · [Persian documentation](docs/README.md) · [Releases](https://github.com/moeinparvizi/movim/releases)

## Install

Download a package from the website or GitHub Releases:

- **Windows x64:** run `movim-Setup.exe`, then open a new PowerShell and run `nvim`. Git for Windows is needed for Git features.
- **macOS, Apple Silicon or Intel:** extract `movim-macOS.zip`, run `Install.command`, and start `movim` in a new terminal. The installer uses Homebrew and needs internet access.
- **Linux x86_64 or ARM64:** install Neovim 0.11+, Git, Node.js/npm, ripgrep and curl, then extract `movim-linux.tar.gz` and run `bash Install.sh`. Start `~/.local/bin/movim`.

The macOS and Linux packages have not been tested on native macOS or Linux machines. See the [English guide](https://moeinparvizi.github.io/movim/docs-en/README.html) for prerequisites, backups, and usage.

## Features

- File explorer, scoped file and text search, and project-wide replacement.
- Language servers for completion, diagnostics, definition, and rename; support depends on the installed server and project setup.
- Project tasks, multiple terminal sessions, debugger integration, and Git tools with conflict resolution.
- Themes, bookmarks, persistent undo, local history, Flash navigation, and multiple cursors.
- Persian keyboard input and a right-to-left window option. Rendering and mixed-direction text depend on Neovim, the terminal, and the font.

Press **Space** to open the shortcut menu. Common shortcuts include `<leader>ff` for files, `<leader>fg` for text search, `<leader>rt` for tasks, `<leader>ut` for themes, and `<leader>gp` for Git pull. See the [full keymap reference](docs/14-keymaps-cheatsheet.md) (Persian).

## Updates

Press **u** on the dashboard, **Space u U**, or run **`:MovimUpdate`** to download and verify the latest stable release. Close all movim windows and reopen to apply it. Workspaces, drafts, searches, themes, personal `user.lua`, and AI credentials are preserved. Modified distribution files stop an update instead of being overwritten. Updates keep backups and recover interrupted writes. See [updates](docs/18-updates.md) for plugin synchronization and the one-time installer upgrade needed by older installations. Native runtimes and launchers still use an in-place installer upgrade; do not uninstall. `:MovimCheckUpdate` checks without installing.

## License

[MIT](LICENSE)

## Release consistency

Every main update builds and validates all platform downloads and deploys the matching website and documentation. Packages include a version, source commit and file hashes in `release.json`; release assets include `SHA256SUMS`. The editor UI is English, and a bundled startup palette keeps the interface readable when plugins or the saved theme are missing. See [release maintenance](installer/RELEASING.md) and [changes](CHANGELOG.md).
