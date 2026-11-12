movim for Linux (x86_64 and ARM64)

1. Install Neovim 0.11+, Git, Node.js/npm, ripgrep and curl through your distribution.
   A compiler and optional fd/lazygit may be needed for additional features.
2. Extract the entire archive and run: bash Install.sh
3. Start ~/.local/bin/movim, or add ~/.local/bin to PATH and run movim.

The installer keeps this configuration separate under XDG_CONFIG_HOME/movim
and backs up a previous movim configuration. Plugins are installed on first run.
