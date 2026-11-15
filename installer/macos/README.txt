movim for macOS

1. Extract the entire ZIP archive.
2. Open Install.command and follow the Terminal prompts. The installer uses
   Homebrew and may request an administrator password to install Homebrew.
3. Open a new Terminal and run: movim
   To open a project: movim /path/to/project
   Alternatively, open ~/Applications/movim.command.

The installer downloads dependencies and plugins, so internet access is needed.
It installs a separate Neovim configuration named web-neovim and backs up an
earlier web-neovim configuration before replacing it. Other Neovim configs are
left in place. The installer includes DejaVuSansM Nerd Font Mono. Select it in your terminal
for Persian glyphs and icons.
If macOS blocks the unsigned installer, use the standard macOS controls for
opening an application from an identified source.
